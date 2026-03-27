import Foundation
import SwiftData

@Model
final class PasteItem {
    var id: UUID
    var content: String
    var title: String
    var remoteURL: String?
    var createdAt: Date
    var expiresAt: Date?
    var isUploaded: Bool
    var isPlainText: Bool
    var isQueued: Bool
    var isEncrypted: Bool
    
    // Media Support
    var mediaType: String = "text" // "text", "image", "file"
    @Attribute(.externalStorage) var binaryData: Data?
    var fileURLString: String?
    
    
    init(
        content: String,
        title: String? = nil,
        remoteURL: String? = nil,
        expiresAt: Date? = nil,
        isPlainText: Bool = false,
        mediaType: String = "text",
        binaryData: Data? = nil,
        fileURLString: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.title = title ?? PasteItem.generateTitle(from: content)
        self.remoteURL = remoteURL
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.isUploaded = remoteURL != nil
        self.isPlainText = isPlainText
        self.isQueued = false
        self.isEncrypted = false
        self.mediaType = mediaType
        self.binaryData = binaryData
        self.fileURLString = fileURLString
    }
    
    /// Returns decrypted content if encrypted, otherwise raw content
    var decryptedContent: String {
        guard isEncrypted else { return content }
        do {
            return try EncryptionService.shared.decrypt(content)
        } catch {
            return content // fallback to raw if decryption fails
        }
    }
    
    static func generateTitle(from content: String) -> String {
        let firstLine = content.components(separatedBy: .newlines).first ?? content
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 200 {
            return String(trimmed.prefix(197)) + "..."
        }
        return trimmed.isEmpty ? "Untitled Paste" : trimmed
    }
    
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var statusSymbol: String {
        if isQueued { return "arrow.clockwise.icloud" }
        if isExpired { return "trash.circle" }
        if isUploaded { return "checkmark.circle.fill" }
        return "doc.text"
    }
}
