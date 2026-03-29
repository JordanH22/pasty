import Foundation
import SwiftUI

/// A highly optimized, lightweight regex syntax highlighter that returns a SwiftUI AttributedString.
/// Designed for extreme performance in the hotkey menu without requiring third-party dependencies.
struct SyntaxHighlighter {
    
    // macOS Dark Mode / Xcode inspired palette (saturated for glass backgrounds)
    private static let keywordColor = NSColor(red: 1.0, green: 0.48, blue: 0.65, alpha: 1.0) // Pink
    private static let stringColor = NSColor(red: 0.99, green: 0.56, blue: 0.35, alpha: 1.0) // Orange/Amber
    private static let commentColor = NSColor(red: 0.44, green: 0.50, blue: 0.56, alpha: 1.0) // Gray
    private static let numberColor = NSColor(red: 0.81, green: 0.65, blue: 0.98, alpha: 1.0) // Purple
    private static let typeColor = NSColor(red: 0.25, green: 0.60, blue: 0.95, alpha: 1.0) // Deeper Blue
    private static let methodColor = NSColor(red: 0.85, green: 0.78, blue: 0.40, alpha: 1.0) // Golden Yellow
    private static let tagColor = NSColor(red: 0.20, green: 0.72, blue: 0.62, alpha: 1.0) // Richer Teal
    private static let decoratorColor = NSColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1.0) // Red
    private static let defaultColor = NSColor.white.withAlphaComponent(0.85)
    
    private static let patterns: [(regex: NSRegularExpression, color: NSColor)] = {
        var rules = [(regex: NSRegularExpression, color: NSColor)]()
        
        // Helper
        func addRule(_ pattern: String, _ color: NSColor) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                rules.append((regex, color))
            }
        }
        
        // 1. Comments
        addRule("(?m)//.*$", commentColor)
        addRule("(?s)/\\*.*?\\*/", commentColor)
        
        // 2. Strings
        addRule("\".*?\"", stringColor)
        addRule("'.*?'", stringColor)
        
        // 3. Keywords
        let keywords = ["let", "var", "func", "struct", "class", "enum", "import", "return", "if", "else", "guard", "switch", "case", "default", "break", "continue", "for", "while", "do", "catch", "throw", "throws", "try", "async", "await", "public", "private", "fileprivate", "internal", "static", "const", "function", "export", "def", "from", "SELECT", "FROM", "WHERE", "ORDER", "BY", "LIMIT", "INSERT", "UPDATE", "DELETE", "true", "false", "null", "nil"]
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        addRule(keywordPattern, keywordColor)
        
        // 4. Numbers
        addRule("\\b\\d+(\\.\\d+)?\\b", numberColor)
        
        // 5. Types (Capitalized identifiers)
        addRule("\\b[A-Z][a-zA-Z0-9]*\\b", typeColor)
        
        // 6. Methods/Functions (words followed by '(')
        addRule("\\b[a-zA-Z_]\\w*(?=\\()", methodColor)
        
        // 7. HTML/XML Tags
        addRule("<[^>]+>", tagColor)
        
        // 8. Decorators / Swift Macros
        addRule("@\\w+", decoratorColor)
        
        return rules
    }()
    // MARK: - Caching
    private class CacheWrapper {
        let attrString: AttributedString
        init(_ attr: AttributedString) { self.attrString = attr }
    }
    
    // NSCache is natively thread-safe, bypass Swift 6 strict checks
    nonisolated(unsafe) private static let cache: NSCache<NSString, CacheWrapper> = {
        let c = NSCache<NSString, CacheWrapper>()
        c.countLimit = 20  // Cap cache to 20 entries to bound memory
        return c
    }()
    
    // MARK: - Core Highlight logic
    
    static func highlight(_ text: String) -> AttributedString {
        let codeSnippet = String(text.prefix(1000))
        let cacheKey = codeSnippet as NSString
        
        if let cached = cache.object(forKey: cacheKey) {
            return cached.attrString
        }
        let nsString = codeSnippet as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        
        let mutAttr = NSMutableAttributedString(string: codeSnippet)
        mutAttr.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
        mutAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), range: fullRange)
        
        // Apply patterns
        for (regex, color) in patterns.reversed() {
            let matches = regex.matches(in: codeSnippet, options: [], range: fullRange)
            for match in matches {
                mutAttr.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        
        // Safely bridge to SwiftUI (Fallback to plain text if bridging fails)
        do {
            let final = try AttributedString(mutAttr, including: \.appKit)
            cache.setObject(CacheWrapper(final), forKey: cacheKey)
            return final
        } catch {
            let fallback = AttributedString(codeSnippet)
            cache.setObject(CacheWrapper(fallback), forKey: cacheKey)
            return fallback
        }
    }
    
    // MARK: - Asynchronous 120Hz ProMotion Parsing
    
    static func highlightAsync(_ text: String) async -> AttributedString {
        // Fast-path for already cached strings
        let cacheKey = String(text.prefix(1000)) as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached.attrString
        }
        
        // Execute regex off the main thread to prevent UI stutter
        return await Task.detached(priority: .userInitiated) {
            return highlight(text)
        }.value
    }
    
    // MARK: - Token-level Parsing
    
    enum TokenType: String {
        case keyword, string, comment, number, type, method, tag, decorator, plain
    }
    
    struct Token: Identifiable {
        let id: String  // Stable: "lineIdx_tokenIdx"
        let text: String
        let type: TokenType
        let color: Color
        
        /// Whether this token is "interesting" (hoverable/clickable)
        var isInteractive: Bool {
            type != .plain && type != .comment
        }
    }
    
    /// Break a single line into colored, interactive tokens.
    static func tokenize(_ line: String, lineIndex: Int = 0) -> [Token] {
        guard !line.isEmpty else {
            return [Token(id: "\(lineIndex)_0", text: " ", type: .plain, color: Color.white.opacity(0.85))]
        }
        
        let nsString = line as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        
        // Build a map of character index → (type, color)
        var charTypes = [(TokenType, Color)](repeating: (.plain, Color.white.opacity(0.85)), count: nsString.length)
        
        let typeMap: [(NSColor, TokenType)] = [
            (keywordColor, .keyword),
            (stringColor, .string),
            (commentColor, .comment),
            (numberColor, .number),
            (typeColor, .type),
            (methodColor, .method),
            (tagColor, .tag),
            (decoratorColor, .decorator)
        ]
        
        // Apply patterns in reverse priority (last pattern wins)
        for (regex, nsColor) in patterns.reversed() {
            let matches = regex.matches(in: line, options: [], range: fullRange)
            let tokenType = typeMap.first(where: { $0.0 == nsColor })?.1 ?? .plain
            let swiftColor = Color(nsColor: nsColor)
            for match in matches {
                for i in match.range.location..<(match.range.location + match.range.length) {
                    if i < charTypes.count {
                        charTypes[i] = (tokenType, swiftColor)
                    }
                }
            }
        }
        
        // Merge consecutive chars with same type into tokens
        let swiftChars = Array(line)
        var tokens: [Token] = []
        var currentText = ""
        var currentType = charTypes[0].0
        var currentColor = charTypes[0].1
        var tokenIdx = 0
        
        for i in 0..<charTypes.count {
            let (type, color) = charTypes[i]
            let ch = i < swiftChars.count ? swiftChars[i] : Character("?")
            if type == currentType {
                currentText.append(ch)
            } else {
                tokens.append(Token(id: "\(lineIndex)_\(tokenIdx)", text: currentText, type: currentType, color: currentColor))
                tokenIdx += 1
                currentText = String(ch)
                currentType = type
                currentColor = color
            }
        }
        if !currentText.isEmpty {
            tokens.append(Token(id: "\(lineIndex)_\(tokenIdx)", text: currentText, type: currentType, color: currentColor))
        }
        
        return tokens
    }
}
