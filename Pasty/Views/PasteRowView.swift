import SwiftUI

struct PasteRowView: View {
    @Environment(AppState.self) private var appState
    let paste: PasteItem
    var isHovered: Bool = false
    var isCopied: Bool = false
    var isExpanded: Bool = false
    var isPinned: Bool = false
    var onCollapse: (() -> Void)? = nil
    @State private var isPlayingVideo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            mainRow
            
            // Expanded preview
            if isExpanded {
                ZStack(alignment: .topTrailing) {
                    previewCard
                    
                    // Collapse chevron
                    if isPinned {
                        Button {
                            onCollapse?()
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
            }
        }
        .padding(Pasty.Spacing.md)
        .glassCard(cornerRadius: Pasty.Radius.md, isHovered: isHovered)
        .animation(Pasty.Motion.spring, value: isHovered)
    }
    
    // MARK: - Main Row
    
    private var mainRow: some View {
        HStack(spacing: Pasty.Spacing.md) {
            // Status icon
            statusIcon
            
            // Content
            VStack(alignment: .leading, spacing: Pasty.Spacing.xs) {
                Text(paste.decryptedContent.components(separatedBy: .newlines).first ?? paste.title)
                    .font(Pasty.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                HStack(spacing: Pasty.Spacing.sm) {
                    Text(paste.timeAgo)
                        .font(Pasty.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    
                    if paste.mediaType == "image" {
                        Label("Image", systemImage: "photo")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .fixedSize()
                    } else if paste.mediaType == "file" {
                        Label("File", systemImage: "doc")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                            .fixedSize()
                    } else if paste.isPlainText {
                        Label("Plain", systemImage: "textformat.size.smaller")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .fixedSize()
                    }
                    
                    if let expiresAt = paste.expiresAt {
                        Label(expiresAt.formatted(.relative(presentation: .named)), systemImage: "timer")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(paste.isExpired ? Pasty.Colors.danger : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .fixedSize()
                    }
                }
                .lineLimit(1)
            }
            
            Spacer()
            
            // Copy feedback
            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Pasty.Colors.success)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Status Icon
    
    private var statusIcon: some View {
        Image(systemName: paste.statusSymbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(statusColor)
            .frame(width: 28, height: 28)
            .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    
    private var statusColor: Color {
        if paste.isQueued { return Pasty.Colors.queued }
        if paste.isExpired { return Pasty.Colors.danger }
        if paste.isUploaded { return Pasty.Colors.success }
        return .secondary
    }
    
    // MARK: - Hover Preview Card
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
            Divider().opacity(0.15)
            
            if paste.mediaType == "image", let data = paste.binaryData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: Pasty.Radius.sm))
            } 
            else if paste.mediaType == "file", let fileURLStr = paste.fileURLString {
                let url = URL(string: fileURLStr) ?? URL(fileURLWithPath: fileURLStr)
                VStack(alignment: .leading, spacing: 4) {
                    // Video thumbnail / inline player
                    if let data = paste.binaryData, let nsImage = NSImage(data: data) {
                        Group {
                            if isPlayingVideo {
                                InlineVideoPlayer(fileURLString: fileURLStr)
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            isPlayingVideo = false
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white.opacity(0.8))
                                                .shadow(radius: 4)
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                            } else {
                                Button {
                                    isPlayingVideo = true
                                } label: {
                                    ZStack {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: Pasty.Radius.sm))
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .shadow(radius: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {}
                    }
                    
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(Pasty.Typography.headline)
                                .lineLimit(1)
                            Text(url.path)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
            } 
            else {
                let content = paste.decryptedContent
                let estimatedLines = content.components(separatedBy: .newlines).count + (content.count / 40)
                let estimatedHeight = min(CGFloat(estimatedLines * 14 + 16), appState.popoverHeight * 0.45)
                
                if appState.codeViewEnabled && CodeDetector.isCode(content) {
                    CodeEditorView(text: content, maxHeight: estimatedHeight)
                } else {
                    // Plain text
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(content)
                            .font(Pasty.Typography.code)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .frame(height: estimatedHeight)
                    .background(Pasty.Colors.glass, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .strokeBorder(Pasty.Colors.glassStroke, lineWidth: 0.3)
                    )
                }
            }
            
            // Meta info
            if let url = paste.remoteURL {
                HStack(spacing: Pasty.Spacing.xs) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                    Text(url)
                        .font(Pasty.Typography.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, Pasty.Spacing.sm)
    }
}

#Preview {
    VStack(spacing: 12) {
        PasteRowView(
            paste: PasteItem(content: "Hello, World!\nThis is a test paste with multiple lines.", remoteURL: "https://dpaste.org/abc123"),
            isHovered: false
        )
        PasteRowView(
            paste: PasteItem(content: "func greet() {\n    print(\"Hello\")\n}", remoteURL: "https://dpaste.org/def456"),
            isHovered: true,
            isExpanded: true
        )
    }
    .padding()
    .frame(width: 400)
}
