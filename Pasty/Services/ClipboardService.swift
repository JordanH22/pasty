import Foundation
import AppKit

final class ClipboardService: @unchecked Sendable {
    static let shared = ClipboardService()
    
    private var lastChangeCount: Int
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    /// Returns the current clipboard string if it has changed since last check
    func checkForNewContent() -> String? {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return nil }
        lastChangeCount = currentCount
        return NSPasteboard.general.string(forType: .string)
    }
    
    /// Returns current clipboard string regardless of change state
    func currentString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    /// Copies a string to the clipboard
    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    
    /// Strips rich text formatting and returns plain text
    func plainText(from string: String) -> String {
        // If we can get an attributed string, convert to plain
        if let data = string.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            return attributed.string
        }
        return string
    }
}
