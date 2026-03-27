import Foundation
import Network
import os.log

final class PasteService: @unchecked Sendable {
    static let shared = PasteService()
    
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.pasty.network-monitor")
    private let logger = Logger(subsystem: "com.pasty.app", category: "network")
    
    private(set) var isOnline: Bool = true
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        self.monitor = NWPathMonitor()
        
        startMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasOffline = !(self?.isOnline ?? true)
            self?.isOnline = path.status == .satisfied
            
            if wasOffline && path.status == .satisfied {
                self?.logger.info("Network restored — ready to flush queue")
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Upload
    
    func upload(content: String, expiry: DestructTimer, serviceURL: String) async throws -> URL {
        guard isOnline else {
            throw PasteError.offline
        }
        
        guard let url = URL(string: serviceURL) else {
            throw PasteError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Add API token if available
        if let token = KeychainService.shared.retrieve(forKey: "pasty_api_token"),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Build form body
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "content", value: content),
            URLQueryItem(name: "format", value: "url"),
            URLQueryItem(name: "lexer", value: "_text")
        ]
        
        if let expiryValue = expiry.seconds {
            bodyComponents.queryItems?.append(
                URLQueryItem(name: "expires", value: String(expiryValue))
            )
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        logger.info("Uploading paste (\(content.count) chars) to \(serviceURL)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasteError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Upload failed: HTTP \(httpResponse.statusCode) — \(body)")
            throw PasteError.serverError(statusCode: httpResponse.statusCode, message: body)
        }
        
        guard let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let pasteURL = URL(string: responseString) else {
            // Try to extract URL from response
            if let responseString = String(data: data, encoding: .utf8),
               let extractedURL = extractURL(from: responseString) {
                logger.info("Paste uploaded: \(extractedURL.absoluteString)")
                return extractedURL
            }
            throw PasteError.invalidResponse
        }
        
        logger.info("Paste uploaded: \(pasteURL.absoluteString)")
        return pasteURL
    }
    
    // MARK: - Helpers
    
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let match = detector?.firstMatch(in: text, range: range)
        return match?.url
    }
}

// MARK: - Errors

enum PasteError: LocalizedError {
    case offline
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No network connection. Paste queued for upload."
        case .invalidURL:
            return "Invalid service URL. Check Settings → API."
        case .invalidResponse:
            return "Unexpected response from paste service."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
