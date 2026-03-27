import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isActivated: Bool = false
    @Published var serialKey: String = ""
    
    private let service = "com.pasty.licenseKey"
    
    private init() {
        self.isActivated = checkActivationStatus()
    }
    
    /// Pentester-grade Hardware validation via Secure Keychain
    private func checkActivationStatus() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let key = String(data: data, encoding: .utf8) {
            self.serialKey = key
            return true
        }
        return false
    }
    
    /// Writes the license payload directly to the macOS encrypted memory enclave.
    private func writeToKeychain(key: String) {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        } else if status == errSecSuccess {
            let attributesToUpdate = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }
    
    /// Remote Execution Validation against Lemon Squeezy MoR
    func validateKey(_ key: String) async throws -> Bool {
        // Simple sanity check before network transit
        let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty else { return false }
        
        // Lemon Squeezy V1 Activation Endpoint
        guard let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = [
            "license_key": cleanedKey,
            "instance_name": Host.current().localizedName ?? "macOS Device"
        ]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let httpRes = response as? HTTPURLResponse
        print("====== LEMON SQUEEZY HTTP TRACE ======")
        print("STATUS CODE: \(httpRes?.statusCode ?? 0)")
        if let rawJSON = String(data: data, encoding: .utf8) {
            print("RAW BODY: \(rawJSON)")
        }
        print("========================================")
        
        guard httpRes?.statusCode == 200 else {
            return false
        }
        
        struct LemonSqueezyResponse: Decodable {
            let activated: Bool
            let error: String?
        }
        
        if let decoded = try? JSONDecoder().decode(LemonSqueezyResponse.self, from: data) {
            if decoded.activated {
                // Permanently embed valid key into Hardware Keychain
                self.writeToKeychain(key: cleanedKey)
                
                // Route UI updates onto the Main Thread safely
                Task { @MainActor in
                    self.serialKey = cleanedKey
                    self.isActivated = true
                }
                return true
            }
        }
        
        return false
    }
    
    func resetActivationForPentesting() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        self.isActivated = false
        self.serialKey = ""
    }
}
