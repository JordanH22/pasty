import SwiftUI

struct SyntaxTextView: View {
    let text: String
    @State private var highlightedAttr: AttributedString?
    
    var body: some View {
        Group {
            if let highlighted = highlightedAttr {
                Text(highlighted)
            } else {
                Text(String(text.prefix(1000)))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .task(id: text) {
            let result = await SyntaxHighlighter.highlightAsync(text)
            withAnimation(.snappy(duration: 0.15)) {
                highlightedAttr = result
            }
        }
    }
}
