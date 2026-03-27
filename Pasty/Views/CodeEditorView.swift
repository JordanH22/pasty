import SwiftUI
import AppKit

struct CodeEditorView: View {
    @Environment(AppState.self) private var appState
    let text: String
    let maxHeight: CGFloat

    @State private var highlighted: AttributedString? = nil
    @State private var hoveredLine: Int? = nil
    @State private var copiedLine: Int? = nil

    private var lines: [String] { text.components(separatedBy: "\n") }
    private var gutterWidth: CGFloat {
        guard appState.showLineNumbers else { return 0 }
        return CGFloat(max(2, String(lines.count).count) * 8 + 16)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if appState.showLineNumbers { lineNumberGutter }

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Group {
                    if let hi = highlighted {
                        Text(hi)
                    } else {
                        Text(String(text.prefix(500)))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .clipped()
        }
        .frame(height: maxHeight)
        .background(Pasty.Colors.glass,
                    in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                    .strokeBorder(Pasty.Colors.glassStroke, lineWidth: 0.3))
        .task(id: text) {
            highlighted = nil
            let result = await SyntaxHighlighter.highlightAsync(text)
            withAnimation(.snappy(duration: 0.15)) { highlighted = result }
        }
    }

    // MARK: - Line Number Gutter

    private var lineNumberGutter: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 4) {
                        if appState.showCopyLineButton && hoveredLine == index {
                            Button { copyLine(index) } label: {
                                Image(systemName: copiedLine == index
                                      ? "checkmark" : "doc.on.clipboard")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(copiedLine == index ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(hoveredLine == index
                                             ? .secondary : Color.white.opacity(0.25))
                    }
                    .frame(width: gutterWidth - 8, alignment: .trailing)
                    .frame(height: 16)
                    .padding(.trailing, 8)
                    .background(hoveredLine == index ? Color.white.opacity(0.04) : Color.clear)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.1)) { hoveredLine = h ? index : nil }
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(width: gutterWidth)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5)
        }
    }

    // MARK: - Actions

    private func copyLine(_ index: Int) {
        guard index < lines.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines[index], forType: .string)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { copiedLine = index }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copiedLine = nil }
        }
    }
}
