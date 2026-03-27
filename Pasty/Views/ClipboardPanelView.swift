import SwiftUI
import AppKit

// MARK: - Liquid Glass Clipboard Panel

struct ClipboardPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var state: ClipboardPanelState
    @State private var hoveredIndex: Int? = nil
    @State private var expandedId: UUID? = nil
    @State private var pinnedIds: Set<UUID> = []
    @State private var expandTask: Task<Void, Never>?
    @State private var playingVideoId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 10) {
            // Header pill
            header
                .background {
                    glassPillBg(cornerRadius: 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
            
            // Content pill
            Group {
                if state.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .background {
                glassPillBg(cornerRadius: 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            
            // Footer pill
            footer
                .background {
                    glassPillBg(cornerRadius: 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        }
        .edgeResizable(
            width: Bindable(appState).hotkeyMenuWidth,
            height: Bindable(appState).hotkeyMenuHeight,
            minWidth: 320, maxWidth: 900,
            minHeight: 300, maxHeight: 1200
        )
        // Authentic iOS entrance spring
        .scaleEffect(state.appeared ? 1 : 0.85)
        .opacity(state.appeared ? 1 : 0)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.03), value: state.appeared)
        .padding(28) // room for shadow + corner drag outset
    }
    
    // MARK: - Glass Pill Background
    
    private func glassPillBg(cornerRadius: CGFloat) -> some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.05))
        }
    }
    
    // MARK: - Header
    
    @State private var clipPulse = false
    
    private var header: some View {
        HStack(spacing: 6) {
            // Animated clipboard glyph with pulse ring
            ZStack {
                // Expanding pulse ring — uses scale to stay perfectly centered
                Circle()
                    .stroke(Color.white.opacity(clipPulse ? 0 : 0.25), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .scaleEffect(clipPulse ? 1.6 : 0.9)
                    .animation(
                        clipPulse ? .easeOut(duration: 2.5).repeatForever(autoreverses: false) : .default,
                        value: clipPulse
                    )
                
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 22, height: 22)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .frame(width: 22, height: 22)
                
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            .frame(width: 30, height: 30)
            .onAppear {
                if state.appeared { clipPulse = true }
            }
            .onChange(of: state.appeared) { _, visible in
                clipPulse = visible
            }
            
            Text("Clipboard")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.7))
            
            Spacer()
            
            if !state.items.isEmpty {
                Text("\(state.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Item List
    
    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                        let isSelected = index == state.selectedIndex
                        let isExpanded = item.id == expandedId || pinnedIds.contains(item.id)
                        let isPinned = pinnedIds.contains(item.id)
                        
                        glassRow(item, index: index, isSelected: isSelected, isExpanded: isExpanded, isPinned: isPinned)
                            .contentShape(Rectangle()) // Enables click-hit-testing on empty space
                            .onTapGesture(count: 2) {
                                state.pasteItem(item)
                            }
                            .onTapGesture {
                                // Single click: toggle pin
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    if pinnedIds.contains(item.id) {
                                        pinnedIds.remove(item.id)
                                    } else {
                                        expandedId = item.id
                                        pinnedIds.insert(item.id)
                                    }
                                }
                            }
                            .id(item.id)
                        .onHover { hovering in
                            // Guard: don't let hover hijack selection before entrance animation settles
                            guard state.appeared, state.hoverSelectionEnabled else { return }
                            // During keyboard navigation, ignore hover — the local mouseMoved
                            // monitor will clear isKeyboardNavigating when mouse actually moves
                            guard !state.isKeyboardNavigating else { return }
                            
                            // Selection highlights instantly
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                hoveredIndex = hovering ? index : nil
                                if hovering {
                                    state.selectedIndex = index
                                }
                            }
                            // Expansion is debounced — only after dwelling 300ms
                            expandTask?.cancel()
                            if hovering {
                                let itemId = item.id
                                expandTask = Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(1000))
                                    guard !Task.isCancelled else { return }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        expandedId = itemId
                                    }
                                }
                            } else {
                                // Don't collapse if pinned, suppressed, or currently expanded
                                // (NSTextView steals SwiftUI hover events so onHover(false) fires
                                //  even when the mouse is still visually inside the expanded row)
                                let isCurrentlyExpanded = expandedId == item.id
                                if !pinnedIds.contains(item.id) && !state.suppressHoverCollapse && !isCurrentlyExpanded {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        expandedId = nil
                                    }
                                }
                            }
                        }
                        // Staggered entrance
                        .opacity(state.appeared ? 1 : 0)
                        .offset(y: state.appeared ? 0 : 14)
                        .scaleEffect(state.appeared ? 1 : 0.88)
                        .animation(
                            .interactiveSpring(response: 0.5, dampingFraction: 0.68, blendDuration: 0.1)
                            .delay(Double(index) * 0.035),
                            value: state.appeared
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: appState.hotkeyMenuWidth) { _, newValue in
                if let window = NSApplication.shared.windows.first(where: { $0.isOpaque == false && $0.level == .floating && $0.hasShadow == false }) {
                    var frame = window.frame
                    let widthDiff = newValue - frame.size.width
                    frame.size.width = newValue
                    frame.origin.x -= widthDiff / 2 // Keep panel centered
                    window.setFrame(frame, display: true, animate: true)
                }
            }
            .onChange(of: appState.hotkeyMenuHeight) { _, newValue in
                if let window = NSApplication.shared.windows.first(where: { $0.isOpaque == false && $0.level == .floating && $0.hasShadow == false }) {
                    var frame = window.frame
                    let diff = newValue - frame.size.height
                    frame.size.height = newValue
                    frame.origin.y -= diff // Push origin down so top stays visually anchored
                    window.setFrame(frame, display: true, animate: false)
                }
            }

            // Auto-scroll and manage expansion when keyboard navigating
            .onChange(of: state.selectedIndex) { _, newIndex in
                guard state.isKeyboardNavigating else { return }
                guard newIndex >= 0, newIndex < state.items.count else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    proxy.scrollTo(state.items[newIndex].id, anchor: .center)
                    // Collapse expanded view when arrow-keying through the list
                    expandedId = nil
                    expandTask?.cancel()
                }
            }
            .onChange(of: state.items.count) { oldCount, newCount in
                // Auto-scroll to keep expanded row visible after new entry inserted
                if newCount > oldCount, let expandedId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            proxy.scrollTo(expandedId)
                        }
                    }
                }
            }
            // expandedId tracks by UUID — no index shifting needed
        }
    }
    
    // MARK: - Glass Row
    
    private func glassRow(_ item: ClipboardHistory.ClipboardEntry, index: Int, isSelected: Bool, isExpanded: Bool, isPinned: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row — always visible
            HStack(spacing: 10) {
                // Status icon
                let symbol = item.isImage ? "photo.fill" : (item.fileURL != nil ? "doc.fill" : "doc.plaintext")
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : (item.isImage ? Color.blue : Color.secondary))
                    .frame(width: 24, height: 24)
                    .background(
                        (isSelected ? Color.accentColor : Color.secondary).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.shortPreview)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(Color.primary.opacity(isSelected ? 1 : 0.6))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(item.timestamp.formatted(.relative(presentation: .named)))
                            .font(.system(size: 9))
                            .foregroundStyle(.primary.opacity(0.3))
                        
                        Text("\(item.content.count) chars")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                
                Spacer()
                
                // Copy/paste feedback
                if isSelected {
                    HStack(spacing: 8) {
                        Button {
                           NSPasteboard.general.clearContents()
                           if item.isImage, let data = item.binaryData, let nsImage = NSImage(data: data) {
                               NSPasteboard.general.writeObjects([nsImage])
                           } else if let fileURLStr = item.fileURL {
                               let url: URL
                               if fileURLStr.hasPrefix("file://") {
                                   url = URL(string: fileURLStr) ?? URL(fileURLWithPath: fileURLStr.replacingOccurrences(of: "file://", with: ""))
                               } else {
                                   url = URL(fileURLWithPath: fileURLStr)
                               }
                               NSPasteboard.general.writeObjects([url as NSURL])
                               NSPasteboard.general.addTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
                               NSPasteboard.general.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
                           } else {
                               NSPasteboard.general.setString(item.content, forType: .string)
                           }
                           
                           ClipboardHistory.shared.bringToTop(item)
                           state.items = ClipboardHistory.shared.items
                           state.selectedIndex = 0
                           
                           state.onDismiss() // Dismiss after manual copy
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                        
                        Button {
                            state.pasteItem(item)
                        } label: {
                            Image(systemName: "return")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction) // Steals Enter back from selectable Text
                        .help("Paste")
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Expanded preview card — slides in on hover/selection
            if isExpanded && (!item.content.isEmpty || item.isImage || item.fileURL != nil) {
                VStack(alignment: .leading, spacing: 4) {
                    Divider().opacity(0.1)
                    
                    if item.isImage, let data = item.binaryData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 4)
                    } 
                    else if let fileURLStr = item.fileURL {
                        let url = URL(string: fileURLStr) ?? URL(fileURLWithPath: fileURLStr)
                        VStack(alignment: .leading, spacing: 4) {
                            // Video thumbnail — tap to play inline
                            if let data = item.binaryData, let nsImage = NSImage(data: data) {
                                Group {
                                    if playingVideoId == item.id {
                                        InlineVideoPlayer(fileURLString: fileURLStr)
                                            .aspectRatio(16/9, contentMode: .fit)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    playingVideoId = nil
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundStyle(.white.opacity(0.8))
                                                        .shadow(radius: 4)
                                                        .padding(4)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                    } else {
                                        Button {
                                            playingVideoId = item.id
                                        } label: {
                                            ZStack {
                                                Image(nsImage: nsImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxHeight: 160)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 28))
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
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    Text(url.path)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 4)
                    } 
                    else {
                        let content = item.content
                        let estimatedLines = content.components(separatedBy: .newlines).count + (content.count / 40)
                        let estimatedHeight = min(CGFloat(estimatedLines * 14 + 16), appState.hotkeyMenuHeight * 0.45)
                        
                        if appState.codeViewEnabled && CodeDetector.isCode(content) {
                            CodeEditorView(text: content, maxHeight: estimatedHeight)
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(String(content.prefix(1000)))
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .frame(height: estimatedHeight)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.3)
                            )
                        }
                    }
                }
                .padding(.top, 6)
                .overlay(alignment: .topTrailing) {
                    if isPinned {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                pinnedIds.remove(item.id)
                                if expandedId == item.id {
                                    expandedId = nil
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .padding(.trailing, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .glassCard(cornerRadius: 14, isHovered: isSelected)
        .animation(Pasty.Motion.spring, value: isSelected)
        .animation(Pasty.Motion.spring, value: isExpanded)
    }
    
    // MARK: - Glass Refraction Line
    
    private var glassRefractLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 10) {
            glassKeyHint("↑↓", label: "select")
            glassKeyHint("⏎", label: "paste")
            glassKeyHint("⌫", label: "remove")
            glassKeyHint("esc", label: "close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
    
    private func glassKeyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 2) {
            Text(key)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 8))
        }
        .foregroundStyle(.primary.opacity(0.3))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 44, height: 44)
                Image(systemName: "clipboard")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.primary.opacity(0.3))
            }
            Text("Nothing copied yet")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(state.appeared ? 1 : 0)
        .scaleEffect(state.appeared ? 1 : 0.8)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: state.appeared)
    }
    
}
