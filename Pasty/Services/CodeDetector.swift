import Foundation

/// Detects whether clipboard text is likely source code vs plain text.
/// Uses a heuristic scoring system — score ≥ 4 = code.
struct CodeDetector {
    
    /// Returns true if the text appears to be source code.
    static func isCode(_ text: String) -> Bool {
        return score(text) >= 4
    }
    
    /// Heuristic score for "code-likeness". Higher = more likely code.
    static func score(_ text: String) -> Int {
        let snippet = String(text.prefix(2000))
        var score = 0
        let lines = snippet.components(separatedBy: .newlines)
        
        // Curly braces
        if snippet.contains("{") || snippet.contains("}") { score += 2 }
        
        // Parentheses or brackets
        if snippet.contains("(") && snippet.contains(")") { score += 1 }
        if snippet.contains("[") && snippet.contains("]") { score += 1 }
        
        // Comment patterns
        if snippet.contains("//") || snippet.contains("/*") || snippet.contains("*/") { score += 3 }
        if snippet.range(of: "(?m)^\\s*#(?!\\s)", options: .regularExpression) != nil { score += 2 }
        
        // Keywords
        let keywords = ["func ", "class ", "struct ", "import ", "def ", "var ", "let ",
                        "const ", "function ", "return ", "async ", "await ", "export ",
                        "SELECT ", "FROM ", "WHERE ", "public ", "private ", "static ",
                        "enum ", "interface ", "module ", "package "]
        let keywordHits = keywords.filter { snippet.contains($0) }.count
        if keywordHits >= 2 { score += 3 }
        else if keywordHits >= 1 { score += 2 }
        
        // Semicolons as line terminators
        if snippet.range(of: ";\\s*$", options: .regularExpression) != nil { score += 2 }
        
        // Assignment operators
        if snippet.contains(" = ") || snippet.contains(" == ") || snippet.contains(" === ") { score += 1 }
        
        // HTML/XML tags
        if snippet.range(of: "<[a-zA-Z][^>]*>", options: .regularExpression) != nil { score += 2 }
        
        // Consistent indentation (3+ lines starting with spaces/tabs)
        let indentedLines = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        if indentedLines.count >= 3 { score += 3 }
        else if indentedLines.count >= 2 { score += 1 }
        
        // Multi-line with short lines (code-like line lengths)
        if lines.count >= 3 { score += 1 }
        
        // Dot notation chains (e.g. object.method.property)
        if snippet.range(of: "\\w+\\.\\w+\\.\\w+", options: .regularExpression) != nil { score += 1 }
        
        return score
    }
}
