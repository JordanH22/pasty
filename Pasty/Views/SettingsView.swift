import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiToken: String = ""
    @State private var showTokenSaved: Bool = false
    @State private var expandedSection: SettingsSection? = nil
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case security = "Security"
        case api = "API"
        case accessibility = "Accessibility"
        case about = "About"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .appearance: "paintbrush"
            case .security: "lock.shield"
            case .api: "network"
            case .accessibility: "keyboard"
            case .about: "info.circle"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Pasty.Spacing.sm) {
                ForEach(SettingsSection.allCases) { section in
                    settingsSectionView(section)
                }
                
                // Quit button
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Quit Pasty")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Pasty.Spacing.sm)
                }
                .buttonStyle(GlassButtonStyle(cornerRadius: Pasty.Radius.md, isPrimary: false))
                .foregroundStyle(Pasty.Colors.danger)
            }
            .padding(Pasty.Spacing.lg)
        }
        .onAppear { loadAPIToken() }
    }
    
    // MARK: - Section Wrapper
    
    private func settingsSectionView(_ section: SettingsSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (tap to expand)
            Button {
                withAnimation(Pasty.Motion.spring) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack(spacing: Pasty.Spacing.md) {
                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    
                    Text(section.rawValue)
                        .font(Pasty.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
                .padding(Pasty.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if expandedSection == section {
                VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                    sectionContent(section)
                }
                .padding(.horizontal, Pasty.Spacing.md)
                .padding(.bottom, Pasty.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
    
    // MARK: - Section Content Router
    
    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .general: generalContent
        case .appearance: appearanceContent
        case .security: securityContent
        case .api: apiContent
        case .accessibility: accessibilityContent
        case .about: aboutContent
        }
    }
    
    // MARK: - General
    
    @MainActor
    private var generalContent: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            Toggle("Auto-capture clipboard on open", isOn: $state.autoCapture)
            Toggle("Plain text by default", isOn: $state.plainTextByDefault)
            launchAtLoginToggle
            
            Divider().opacity(0.15)
            
            HStack {
                Text("Default destruct timer")
                Spacer()
                Picker("", selection: $state.defaultDestructTimer) {
                    ForEach(DestructTimer.allCases) { timer in
                        Text(timer.rawValue).tag(timer)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)
            }
            
            HStack {
                Text("History limit")
                Spacer()
                Picker("", selection: $state.historyLimit) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            Divider().opacity(0.15)
            
            // Screenshot auto-capture info
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.blue)
                    .font(.system(size: 13))
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screenshot auto-capture")
                        .font(Pasty.Typography.body)
                        .fontWeight(.medium)
                    
                    Text("Screenshots are automatically added to your Pasty history when they're saved. No extra permissions required.")
                        .font(Pasty.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .lineSpacing(2)
                }
            }
        }
        .font(Pasty.Typography.body)
    }
    
    // MARK: - Appearance
    
    @MainActor
    private var appearanceContent: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            
            Text("Top Menu Dropdown")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
            HStack {
                Text("Width")
                Spacer()
                Text("\(Int(state.popoverWidth))px")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $state.popoverWidth, in: 320...600, step: 10)
            
            HStack {
                Text("Height")
                Spacer()
                Text("\(Int(state.popoverHeight))px")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $state.popoverHeight, in: 400...700, step: 10)
            
            Divider().opacity(0.15)
            
            Text("Floating Hotkey Menu")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
            HStack {
                Text("Width")
                Spacer()
                Text("\(Int(state.hotkeyMenuWidth))px")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $state.hotkeyMenuWidth, in: 320...800, step: 10)
            
            HStack {
                Text("Height")
                Spacer()
                Text("\(Int(state.hotkeyMenuHeight))px")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $state.hotkeyMenuHeight, in: 320...1200, step: 10)
            
            Divider().opacity(0.15)
            
            Text("Expanded View")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
            
            Toggle(isOn: $state.codeViewEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Code View")
                    Text("IDE-style view for code pastes (line numbers, token highlighting)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Toggle(isOn: $state.syntaxHighlighting) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Syntax Highlighting")
                    Text("Colored code tokens in expanded preview")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(!state.codeViewEnabled)
            .opacity(state.codeViewEnabled ? 1 : 0.4)
            
            Toggle(isOn: $state.showLineNumbers) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Line Numbers")
                    Text("Show line number gutter")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(!state.codeViewEnabled)
            .opacity(state.codeViewEnabled ? 1 : 0.4)
            
            Toggle(isOn: $state.showCopyLineButton) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copy Line Button")
                    Text("Clipboard icon on hover to copy a single line")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(!state.codeViewEnabled)
            .opacity(state.codeViewEnabled ? 1 : 0.4)
        }
        .font(Pasty.Typography.body)
    }
    
    // MARK: - Security
    
    @MainActor
    private var securityContent: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            Toggle("Encrypt paste history (AES-256-GCM)", isOn: $state.secureHistory)
            
            if state.secureHistory {
                HStack(spacing: Pasty.Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Pasty.Colors.success)
                        .font(.system(size: 12))
                    Text("Encrypted with a Keychain-backed key")
                        .font(Pasty.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("No analytics or telemetry data is collected.")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .font(Pasty.Typography.body)
    }
    
    // MARK: - API
    
    @MainActor
    private var apiContent: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            Toggle("Show Upload & Copy URL button", isOn: $state.showUploadButton)
                .animation(Pasty.Motion.spring, value: appState.showUploadButton)
            
            Text("When enabled, a button appears on the New Paste tab to upload your clipboard text to a paste service and copy the shareable URL.")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.tertiary)
                .lineSpacing(2)
            
            if state.showUploadButton {
                Divider().opacity(0.15)
                
                TextField("Enter paste service URL", text: $state.pasteServiceURL)
                    .textFieldStyle(.roundedBorder)
                    .font(Pasty.Typography.body)
                
                Divider().opacity(0.15)
                
                HStack {
                    SecureField("API token (optional)", text: $apiToken)
                        .textFieldStyle(.roundedBorder)
                        .font(Pasty.Typography.body)
                    
                    Button {
                        saveAPIToken()
                    } label: {
                        if showTokenSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Pasty.Colors.success)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(GlassButtonStyle(isPrimary: false))
                }
                
                Text("Stored securely in the macOS Keychain")
                    .font(Pasty.Typography.caption)
                    .foregroundStyle(.tertiary)
                
                Divider().opacity(0.15)
                
                // Security warning
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                    
                    Text("Your local clipboard history is fully encrypted with AES-256-GCM. However, uploaded pastes are sent to an external service outside of Pasty's control. Only use this feature for non-sensitive, quick-share content.")
                        .font(Pasty.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
        .animation(Pasty.Motion.spring, value: appState.showUploadButton)
    }
    
    // MARK: - Accessibility
    
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityPollTimer: Timer?
    @AppStorage("globalHotkey") private var globalHotkey: String = GlobalHotkey.cmdShiftV.rawValue
    
    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            // Hotkey Configuration
            HStack {
                HStack(spacing: Pasty.Spacing.sm) {
                    Image(systemName: "keyboard.fill")
                        .foregroundStyle(.blue)
                    Text("Global shortcut")
                        .font(Pasty.Typography.body)
                }
                
                Spacer()
                
                Picker("", selection: $globalHotkey) {
                    ForEach(GlobalHotkey.allCases) { hotkey in
                        Text(hotkey.title).tag(hotkey.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .onChange(of: globalHotkey) { _ in
                    HotkeyManager.shared.reload()
                }
            }
            
            Text(GlobalHotkey(rawValue: globalHotkey)?.description ?? "")
                .font(Pasty.Typography.caption)
                .foregroundStyle(.secondary)
            
            Divider().opacity(0.15)
            
            // Auto-paste permission
            HStack(spacing: Pasty.Spacing.sm) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accessibilityGranted ? Pasty.Colors.success : .orange)
                Text(accessibilityGranted ? "Auto-paste enabled" : "Auto-paste requires Accessibility")
                    .font(Pasty.Typography.body)
                    .foregroundStyle(accessibilityGranted ? Pasty.Colors.success : .primary)
            }
            
            if accessibilityGranted {
                Text("When you press Enter in the clipboard panel, Pasty will automatically paste into the active app.")
                    .font(Pasty.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(2)
            } else {
                Text("Pasty needs Accessibility permission to simulate ⌘V and paste into other apps. Without it, items are copied to clipboard and you paste manually.")
                    .font(Pasty.Typography.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                
                Button {
                    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                    // Re-check after a short delay (user might flip the toggle)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation(Pasty.Motion.spring) {
                            accessibilityGranted = AXIsProcessTrusted()
                        }
                    }
                } label: {
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "gear")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Open Accessibility Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Pasty.Spacing.sm)
                }
                .buttonStyle(GlassButtonStyle(cornerRadius: Pasty.Radius.sm, isPrimary: true))
                
                Text("Toggle Pasty on in System Settings → Privacy & Security → Accessibility.")
                    .font(Pasty.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            // Poll every 2 seconds so the checkmark updates automatically
            accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in
                    let granted = AXIsProcessTrusted()
                    if granted != accessibilityGranted {
                        withAnimation(Pasty.Motion.spring) {
                            accessibilityGranted = granted
                        }
                    }
                }
            }
        }
        .onDisappear {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
        }
    }
    
    // MARK: - About
    
    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
            infoRow("Version", value: "1.0.0")
            infoRow("Framework", value: "SwiftUI + SwiftData")
            infoRow("Architecture", value: "Universal")
            infoRow("RAM Target", value: "< 35 MB")
            infoRow("Binary Target", value: "< 10 MB")
        }
    }
    
    // MARK: - Helpers
    
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Pasty.Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Pasty.Typography.body)
                .fontWeight(.medium)
        }
    }
    
    private func loadAPIToken() {
        apiToken = KeychainService.shared.retrieve(forKey: "pasty_api_token") ?? ""
    }
    
    private func saveAPIToken() {
        KeychainService.shared.save(apiToken, forKey: "pasty_api_token")
        withAnimation(Pasty.Motion.quickSpring) { showTokenSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(Pasty.Motion.quickSpring) { showTokenSaved = false }
        }
    }
    
    // MARK: - Launch at Login
    
    private var launchAtLoginToggle: some View {
        Toggle("Launch at login", isOn: Binding(
            get: {
                SMAppService.mainApp.status == .enabled
            },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Silently fail — ad-hoc signed apps can't register
                }
            }
        ))
    }
}

#Preview {
    SettingsView()
        .frame(width: 420, height: 500)
        .environment(AppState())
}
