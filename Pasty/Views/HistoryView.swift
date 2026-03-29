import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var allPastes: [PasteItem] = []
    @State private var searchText: String = ""
    @State private var hoveredPasteID: UUID?
    @State private var copiedPasteID: UUID?
    @State private var expandedPasteID: UUID?
    @State private var pinnedPasteIDs: Set<UUID> = []
    @State private var expandTask: Task<Void, Swift.Error>?
    @State private var collapseTask: Task<Void, Never>?
    @State private var suppressHoverCollapse: Bool = false
    @State private var cachedFilteredPastes: [PasteItem] = []
    
    private var filteredPastes: [PasteItem] {
        cachedFilteredPastes
    }
    
    private func recomputeFilteredPastes() {
        if searchText.isEmpty {
            cachedFilteredPastes = Array(allPastes.prefix(appState.historyLimit))
        } else {
            cachedFilteredPastes = allPastes.filter { paste in
                paste.title.localizedCaseInsensitiveContains(searchText) ||
                paste.decryptedContent.localizedCaseInsensitiveContains(searchText)
            }.prefix(appState.historyLimit).map { $0 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, Pasty.Spacing.lg)
                .padding(.top, Pasty.Spacing.md)
                .padding(.bottom, Pasty.Spacing.sm)
            
            Divider().opacity(0.1)
            
            // Paste list
            if filteredPastes.isEmpty {
                emptyState
            } else {
                pasteList
            }
        }
        .onAppear {
            fetchPastes()
            ClipboardHistory.shared.onChange = {
                DispatchQueue.main.async {
                    self.fetchPastes()
                    self.suppressHoverCollapse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.suppressHoverCollapse = false
                    }
                }
            }
        }
        .onDisappear {
            ClipboardHistory.shared.onChange = nil
            // Release fetched objects from RAM when leaving History tab
            allPastes = []
            cachedFilteredPastes = []
        }
        .onChange(of: searchText) { _, _ in
            recomputeFilteredPastes()
        }
    }
    
    private func fetchPastes() {
        var descriptor = FetchDescriptor<PasteItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = appState.historyLimit + 10 // Slight buffer for filtering
        if let fetched = try? modelContext.fetch(descriptor) {
            allPastes = fetched
            recomputeFilteredPastes()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: Pasty.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            
            TextField("Search pastes...", text: $searchText)
                .textFieldStyle(.plain)
                .font(Pasty.Typography.body)
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(Pasty.Motion.quickSpring) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, Pasty.Spacing.md)
        .padding(.vertical, Pasty.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                .strokeBorder(Pasty.Colors.glassStroke, lineWidth: Pasty.Glass.strokeWidth)
        )
    }
    
    // MARK: - Paste List
    
    private var pasteList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Pasty.Spacing.sm) {
                    ForEach(Array(filteredPastes.enumerated()), id: \.element.id) { index, paste in
                        let isSelected = index == appState.popoverSelectedIndex
                        
                        PasteRowView(
                            paste: paste,
                            isHovered: isSelected || hoveredPasteID == paste.id,
                            isCopied: copiedPasteID == paste.id,
                            isExpanded: expandedPasteID == paste.id || pinnedPasteIDs.contains(paste.id),
                            isPinned: pinnedPasteIDs.contains(paste.id),
                            onCollapse: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    pinnedPasteIDs.remove(paste.id)
                                    if expandedPasteID == paste.id {
                                        expandedPasteID = nil
                                    }
                                }
                            }
                        )
                        .overlay {
                            if paste.isPending {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    
                                    HStack(spacing: Pasty.Spacing.sm) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Saving Screen Recording...")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: paste.isPending)
                        .allowsHitTesting(!paste.isPending)
                        .id(paste.id)
                        .onHover { isHovering in
                            guard appState.popoverHoverEnabled,
                                  !appState.popoverKeyboardNavigating else { return }
                            
                            withAnimation(Pasty.Motion.quickSpring) {
                                hoveredPasteID = isHovering ? paste.id : nil
                                if isHovering {
                                    appState.popoverSelectedIndex = index
                                }
                            }
                            
                            expandTask?.cancel()
                            collapseTask?.cancel()
                            if isHovering {
                                expandTask = Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(1000))
                                    guard !Task.isCancelled else { return }
                                    // Suppress collapse briefly — the expansion shifts layout,
                                    // which moves the row out from under the cursor triggering
                                    // a false onHover(false) event
                                    suppressHoverCollapse = true
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        expandedPasteID = paste.id
                                    }
                                    try? await Task.sleep(for: .milliseconds(600))
                                    guard !Task.isCancelled else { return }
                                    suppressHoverCollapse = false
                                }
                            } else {
                                // Don't collapse if pinned or in suppression window
                                if !pinnedPasteIDs.contains(paste.id) && !suppressHoverCollapse {
                                    // Delay before collapsing — matches hotkey panel feel
                                    collapseTask = Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(500))
                                        guard !Task.isCancelled else { return }
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            expandedPasteID = nil
                                        }
                                    }
                                }
                            }
                        }
                        .onTapGesture {
                            // Single click: toggle pin
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if pinnedPasteIDs.contains(paste.id) {
                                    pinnedPasteIDs.remove(paste.id)
                                } else {
                                    expandedPasteID = paste.id
                                    pinnedPasteIDs.insert(paste.id)
                                }
                            }
                        }
                        .onTapGesture(count: 2) {
                            copyPasteURL(paste)
                        }
                        .contextMenu {
                            contextMenuItems(for: paste)
                        }
                    }
                }
                .padding(.horizontal, Pasty.Spacing.lg)
                .padding(.vertical, Pasty.Spacing.sm)
                // Identity managed by ForEach paste.id — no forced rebuild
            }
            .onChange(of: allPastes.count) { oldCount, newCount in
                if newCount > oldCount {
                    suppressHoverCollapse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        suppressHoverCollapse = false
                    }
                }
            }
            .onChange(of: appState.popoverSelectedIndex) { _, newIndex in
                guard appState.popoverKeyboardNavigating else { return }
                let pastes = filteredPastes
                guard newIndex >= 0, newIndex < pastes.count else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    proxy.scrollTo(pastes[newIndex].id, anchor: .center)
                    expandedPasteID = nil
                    expandTask?.cancel()
                }
            }

            .onAppear {
                appState.popoverItemCount = filteredPastes.count
            }
            .onChange(of: filteredPastes.count) { _, newCount in
                appState.popoverItemCount = newCount
            }

        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: Pasty.Spacing.lg) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            
            VStack(spacing: Pasty.Spacing.xs) {
                Text(searchText.isEmpty ? "No Pastes Yet" : "No Results")
                    .font(Pasty.Typography.headline)
                    .foregroundStyle(.secondary)
                
                Text(searchText.isEmpty
                     ? "Copy something to your clipboard and it will appear here."
                     : "Try a different search term.")
                    .font(Pasty.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Pasty.Spacing.xl)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems(for paste: PasteItem) -> some View {
        if let url = paste.remoteURL {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            } label: {
                Label("Copy URL", systemImage: "link")
            }
        }
        
        Button {
            NSPasteboard.general.clearContents()
            if paste.mediaType == "image", let data = paste.binaryData, let nsImage = NSImage(data: data) {
                NSPasteboard.general.writeObjects([nsImage])
            } else if paste.mediaType == "file", let fileURLStr = paste.fileURLString, let url = URL(string: fileURLStr) {
                NSPasteboard.general.writeObjects([url as NSURL])
            } else {
                NSPasteboard.general.setString(paste.decryptedContent, forType: .string)
            }
        } label: {
            Label("Copy Content", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            withAnimation(Pasty.Motion.spring) {
                modelContext.delete(paste)
                fetchPastes()
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func copyPasteURL(_ paste: PasteItem) {
        NSPasteboard.general.clearContents()
        
        if paste.mediaType == "image", let data = paste.binaryData, let nsImage = NSImage(data: data) {
            NSPasteboard.general.writeObjects([nsImage])
        } else if paste.mediaType == "file", let fileURLStr = paste.fileURLString, let url = URL(string: fileURLStr) {
            NSPasteboard.general.writeObjects([url as NSURL])
        } else {
            let textToCopy = paste.remoteURL ?? paste.decryptedContent
            NSPasteboard.general.setString(textToCopy, forType: .string)
        }
        
        withAnimation(Pasty.Motion.spring) {
            copiedPasteID = paste.id
        }
        
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(Pasty.Motion.spring) {
                if copiedPasteID == paste.id { copiedPasteID = nil }
            }
        }
    }
    
}

#Preview {
    HistoryView()
        .frame(width: 420, height: 400)
        .environment(AppState())
        .modelContainer(for: PasteItem.self, inMemory: true)
}
