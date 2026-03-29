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
    @State private var cachedIsCode: Bool?
    
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
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .clipped()
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
                Text(paste.title)
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
            
            // Action buttons for images/screenshots (visible on hover)
            if isHovered, paste.mediaType == "image", let data = paste.binaryData {
                HStack(spacing: 4) {
                    Button {
                        openInMarkup(imageData: data)
                    } label: {
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Markup")
                    
                    Button {
                        shareImage(data: data)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Share")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
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
                VStack(spacing: Pasty.Spacing.sm) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: Pasty.Radius.sm))
                    
                    // Action buttons — Edit & Share
                    HStack(spacing: Pasty.Spacing.sm) {
                        // Markup / Edit button
                        Button {
                            openInMarkup(imageData: data)
                        } label: {
                            Label("Markup", systemImage: "pencil.tip.crop.circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        // Share button
                        Button {
                            shareImage(data: data)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        Spacer()
                    }
                }
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
                    
                    // Open & Share actions for files
                    HStack(spacing: Pasty.Spacing.sm) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open", systemImage: "arrow.up.forward.square")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        Button {
                            shareFile(url: url)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
            } 
            else {
                let content = paste.decryptedContent
                let estimatedLines = content.filter { $0 == "\n" }.count + (content.count / 40)
                let estimatedHeight = max(60, min(CGFloat(estimatedLines * 14 + 16), appState.popoverHeight * 0.45))
                
                let isCode = cachedIsCode ?? {
                    let result = CodeDetector.isCode(content)
                    DispatchQueue.main.async { cachedIsCode = result }
                    return result
                }()
                
                if appState.codeViewEnabled && isCode {
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
    
    // MARK: - Actions
    
    /// Opens the image in Preview.app for Markup editing
    private func openInMarkup(imageData: Data) {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Pasty_Screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        // Convert to PNG if needed
        if let image = NSImage(data: imageData),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        } else {
            try? imageData.write(to: fileURL)
        }
        
        NSWorkspace.shared.open(fileURL)
    }
    
    /// Shows the native macOS share sheet for the image
    private func shareImage(data: Data) {
        guard let image = NSImage(data: data) else { return }
        
        let picker = NSSharingServicePicker(items: [image])
        
        // Find the key window's content view to anchor the picker
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
           let contentView = window.contentView {
            let rect = CGRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }
    
    private func shareFile(url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
           let contentView = window.contentView {
            let rect = CGRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
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
