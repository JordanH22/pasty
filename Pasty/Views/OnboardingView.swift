import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @AppStorage("globalHotkey") private var globalHotkey: String = GlobalHotkey.cmdShiftV.rawValue
    
    @State private var isHoveringHotkey = false
    @State private var isHoveringAccessibility = false
    
    // Poll for accessibility status
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Pasty.Spacing.xl) {
                    Spacer().frame(height: 50)
                    
                    // Icon
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)
                    
                    // Title
                    VStack(spacing: Pasty.Spacing.sm) {
                        Text("Welcome to Pasty")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        
                        Text("A lightweight, beautiful pastebin\nright in your menu bar.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                        featureRow(icon: "chevron.left.forwardslash.chevron.right", color: .blue,
                                  title: "Syntax-Highlighted Code View",
                                  subtitle: "Auto-detects 30+ languages with line numbers")
                        
                        featureRow(icon: "pin.fill", color: .orange,
                                  title: "Pin & Expand Previews",
                                  subtitle: "Hover to peek, click to pin — fluid spring animations")
                        
                        featureRow(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", color: .purple,
                                  title: "Searchable History",
                                  subtitle: "Scroll through your last 50 pastes with frictionless ease")
                        
                        featureRow(icon: "lock.shield.fill", color: .green,
                                  title: "Private & Encrypted",
                                  subtitle: "AES-256 local storage — your data never leaves your Mac")
                    }
                    .padding(.horizontal, Pasty.Spacing.lg)
                    
                    Divider().opacity(0.2).padding(.horizontal, Pasty.Spacing.xl)
                    
                    // Hotkey Customization
                    hotkeySelectionSection
                        .padding(.horizontal, Pasty.Spacing.lg)
                    
                    Divider().opacity(0.2).padding(.horizontal, Pasty.Spacing.xl)
                    
                    // Accessibility section
                    accessibilitySection
                        .padding(.horizontal, Pasty.Spacing.lg)
                }
                .padding(.horizontal, Pasty.Spacing.xl)
                .padding(.bottom, Pasty.Spacing.xl)
            
            // Bottom bar
            bottomBar
        }
        .frame(width: 520, height: 760)
        .background(.ultraThinMaterial)
        .onReceive(timer) { _ in
            let granted = AXIsProcessTrusted()
            if granted != accessibilityGranted {
                withAnimation(Pasty.Motion.spring) {
                    accessibilityGranted = granted
                }
            }
        }
    }
    
    // MARK: - Accessibility Section
    
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            HStack(spacing: Pasty.Spacing.sm) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "keyboard.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accessibilityGranted ? Pasty.Colors.success : .orange)
                
                let selectedTitle = GlobalHotkey(rawValue: globalHotkey)?.title ?? "⌘ ⇧ V"
                Text("Global Hotkey — \(selectedTitle)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            
            if accessibilityGranted {
                HStack(spacing: Pasty.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Pasty.Colors.success)
                        .font(.system(size: 13))
                    Text("Accessibility permission granted — you're all set!")
                        .font(.system(size: 13))
                        .foregroundStyle(Pasty.Colors.success)
                }
                .padding(Pasty.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Pasty.Colors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                    let selectedTitle = GlobalHotkey(rawValue: globalHotkey)?.title ?? "⌘ ⇧ V"
                    Text("To use \(selectedTitle) from any app, Pasty needs Accessibility access.\nThis only allows detecting your shortcut — nothing else is read.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    
                    // What it does / doesn't do
                    VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                        explanationRow(icon: "keyboard.fill", color: .blue,
                                      text: "Detects your hotkey from any application")
                        explanationRow(icon: "eye.slash.fill", color: .green,
                                      text: "Cannot read what you type — only the shortcut")
                        explanationRow(icon: "lock.fill", color: .purple,
                                      text: "Your data never leaves your Mac")
                    }
                    .padding(Pasty.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .fill(.white.opacity(isHoveringAccessibility ? 0.08 : 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isHoveringAccessibility ? 0.8 : 0.5),
                                        .white.opacity(isHoveringAccessibility ? 0.2 : 0.1),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isHoveringAccessibility ? 2.0 : 1.5
                            )
                    )
                    .shadow(color: .black.opacity(isHoveringAccessibility ? 0.3 : 0.2), radius: isHoveringAccessibility ? 12 : 8, y: isHoveringAccessibility ? 6 : 4)
                    .scaleEffect(isHoveringAccessibility ? 1.01 : 1.0)
                    .onHover { isHoveringAccessibility = $0 }
                    .animation(Pasty.Motion.spring, value: isHoveringAccessibility)
                    
                    // Open Settings button
                    Button {
                        // Drop the Pasty Onboarding window level so the macOS Accessibility dialog can physically render IN FRONT of it.
                        if let window = NSApplication.shared.windows.first(where: { $0.title == "Welcome to Pasty" }) {
                            window.level = .normal
                        }
                        
                        // Force macOS to add Pasty to the Accessibility list quietly
                        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                        
                        // Then explicitly open the Accessibility pane so they can toggle it
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    } label: {
                        HStack(spacing: Pasty.Spacing.sm) {
                            Image(systemName: "gear")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Open Accessibility Settings")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Pasty.Spacing.sm)
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: Pasty.Radius.sm, isPrimary: true))
                    
                    Text("Toggle Pasty on in the list, then come back here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .transition(.opacity)
            }
        }
        .padding(Pasty.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous)
                .strokeBorder(
                    (accessibilityGranted ? Pasty.Colors.success : Color.orange).opacity(0.3),
                    lineWidth: Pasty.Glass.strokeWidth
                )
        )
        .animation(Pasty.Motion.spring, value: accessibilityGranted)
    }
    
    // MARK: - Hotkey Section
    
    private var hotkeySelectionSection: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            HStack(spacing: Pasty.Spacing.sm) {
                Image(systemName: "command.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Choose Your Hotkey")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            
            VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                Text("Pick your preferred global shortcut to instantly summon Pasty.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                
                HStack {
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
                    
                    Spacer()
                    
                    Text(GlobalHotkey(rawValue: globalHotkey)?.description ?? "")
                        .font(Pasty.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Pasty.Spacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                        .fill(isHoveringHotkey ? .blue.opacity(0.08) : .white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    isHoveringHotkey ? .blue.opacity(0.6) : .white.opacity(0.5),
                                    .white.opacity(isHoveringHotkey ? 0.2 : 0.1),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHoveringHotkey ? 2.0 : 1.5
                        )
                )
                .shadow(color: isHoveringHotkey ? .blue.opacity(0.25) : .black.opacity(0.2), radius: isHoveringHotkey ? 14 : 8, y: isHoveringHotkey ? 6 : 4)
                .scaleEffect(isHoveringHotkey ? 1.015 : 1.0)
                
                if isHoveringHotkey {
                    Text(GlobalHotkey(rawValue: globalHotkey)?.detailedDescription ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onHover { isHoveringHotkey = $0 }
        .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isHoveringHotkey)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            Text("You can always skip — the menu bar icon works without this.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(GlassButtonStyle(isPrimary: true))
        }
        .padding(Pasty.Spacing.xl)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helpers
    
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: Pasty.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func explanationRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Pasty.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
