import SwiftUI
import SwiftData

struct NewPasteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var pasteContent: String = ""
    @State private var destructTimer: DestructTimer = .never
    @State private var isPlainText: Bool = false
    @State private var isUploading: Bool = false
    @State private var showCopiedFeedback: Bool = false
    @State private var uploadError: String?
    
    var body: some View {
        VStack(spacing: Pasty.Spacing.md) {
            // Editor
            editor
            
            // Controls bar
            controlsBar
            
            // Upload button (opt-in via Settings)
            if appState.showUploadButton {
                uploadButton
            }
        }
        .padding(Pasty.Spacing.lg)
        .onAppear {
            if appState.autoCapture {
                captureClipboard()
            }
            destructTimer = appState.defaultDestructTimer
            isPlainText = appState.plainTextByDefault
        }
    }
    
    // MARK: - Editor
    
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Glass text area
            TextEditor(text: $pasteContent)
                .font(Pasty.Typography.code)
                .scrollContentBackground(.hidden)
                .padding(Pasty.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Placeholder
            if pasteContent.isEmpty {
                Text("Paste or type your content here...")
                    .font(Pasty.Typography.code)
                    .foregroundStyle(.tertiary)
                    .padding(Pasty.Spacing.md)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous)
                .strokeBorder(Pasty.Colors.glassStroke, lineWidth: Pasty.Glass.strokeWidth)
        )
    }
    
    // MARK: - Controls
    
    private var controlsBar: some View {
        HStack(spacing: Pasty.Spacing.md) {
            // Plain text toggle
            Toggle(isOn: $isPlainText) {
                Label("Plain Text", systemImage: "textformat.size.smaller")
                    .font(Pasty.Typography.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            
            Spacer()
            
            // Destruct timer
            HStack(spacing: Pasty.Spacing.xs) {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $destructTimer) {
                    ForEach(DestructTimer.allCases) { timer in
                        Text(timer.rawValue).tag(timer)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)
                .controlSize(.small)
            }
            
            // Character count
            Text("\(pasteContent.count) chars")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, Pasty.Spacing.xs)
    }
    
    // MARK: - Upload Button
    
    private var uploadButton: some View {
        VStack(spacing: Pasty.Spacing.sm) {
            Button {
                Task { await uploadPaste() }
            } label: {
                HStack(spacing: Pasty.Spacing.sm) {
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else if showCopiedFeedback {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("URL Copied!")
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Upload & Copy URL")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Pasty.Spacing.sm)
            }
            .buttonStyle(GlassButtonStyle(cornerRadius: Pasty.Radius.md, isPrimary: true))
            .disabled(pasteContent.isEmpty || isUploading)
            .opacity(pasteContent.isEmpty ? 0.5 : 1.0)
            .animation(Pasty.Motion.quickSpring, value: showCopiedFeedback)
            .animation(Pasty.Motion.quickSpring, value: isUploading)
            
            if let error = uploadError {
                Text(error)
                    .font(Pasty.Typography.caption)
                    .foregroundStyle(Pasty.Colors.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Actions
    
    private func captureClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string),
           !clipboardString.isEmpty {
            pasteContent = isPlainText ? clipboardString.strippingFormatting() : clipboardString
        }
    }
    
    private func uploadPaste() async {
        guard !pasteContent.isEmpty else { return }
        
        isUploading = true
        uploadError = nil
        
        let content = isPlainText ? pasteContent.strippingFormatting() : pasteContent
        
        // Calculate expiry
        let expiresAt: Date? = destructTimer.seconds.map { Date().addingTimeInterval(TimeInterval($0)) }
        
        // Create local record
        let pasteItem = PasteItem(
            content: content,
            expiresAt: expiresAt,
            isPlainText: isPlainText
        )
        modelContext.insert(pasteItem)
        
        do {
            let url = try await PasteService.shared.upload(
                content: content,
                expiry: destructTimer,
                serviceURL: appState.pasteServiceURL
            )
            
            pasteItem.remoteURL = url.absoluteString
            pasteItem.isUploaded = true
            
            // Copy URL to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            
            // Show feedback
            withAnimation(Pasty.Motion.spring) {
                showCopiedFeedback = true
            }
            
            try? await Task.sleep(for: .seconds(2))
            
            withAnimation(Pasty.Motion.spring) {
                showCopiedFeedback = false
                pasteContent = ""
            }
            
        } catch {
            // Queue for later if offline
            if !appState.isOnline {
                pasteItem.isQueued = true
                appState.pendingUploadCount += 1
                uploadError = "Queued for upload when online"
            } else {
                uploadError = error.localizedDescription
            }
        }
        
        isUploading = false
        
        // Enforce history limit
        enforceHistoryLimit()
    }
    
    private func enforceHistoryLimit() {
        let fetchDescriptor = FetchDescriptor<PasteItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let allPastes = try? modelContext.fetch(fetchDescriptor),
           allPastes.count > appState.historyLimit {
            for paste in allPastes.dropFirst(appState.historyLimit) {
                modelContext.delete(paste)
            }
        }
    }
}

// MARK: - String Extension

extension String {
    func strippingFormatting() -> String {
        // Return plain text by stripping any potential rich text artifacts
        return self.components(separatedBy: .controlCharacters).joined()
    }
}

#Preview {
    NewPasteView()
        .frame(width: 420, height: 400)
        .environment(AppState())
        .modelContainer(for: PasteItem.self, inMemory: true)
}
