import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @AppStorage("globalHotkey") private var globalHotkey: String = GlobalHotkey.cmdShiftV.rawValue
    
    @State private var isHoveringHotkey = false
    @State private var isHoveringAccessibility = false
    @State private var isHoveringDesktop = false
    @State private var desktopAccessGranted = false
    @AppStorage("secureHistory") private var secureHistory = false
    @State private var showKeychainNote = false
    @State private var encryptionConfirmed = false
    @State private var hasScrolled = false
    @State private var scrollChevronBounce = false
    
    // Poll for accessibility status
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(spacing: Pasty.Spacing.md) {
                    Spacer().frame(height: 20)
                    
                    // Icon
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)
                    
                    // Title
                    VStack(spacing: 4) {
                        Text("Welcome to Pasty")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                        Text("A lightweight, beautiful pastebin right in your menu bar.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Features — compact 2-column centered grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .center, spacing: Pasty.Spacing.sm) {
                        featureRow(icon: "camera.viewfinder", color: .cyan,
                                  title: "Screenshot Capture",
                                  subtitle: "⌘⇧4 appears instantly")
                        
                        featureRow(icon: "chevron.left.forwardslash.chevron.right", color: .blue,
                                  title: "Code Highlighting",
                                  subtitle: "30+ languages")
                        
                        featureRow(icon: "pin.fill", color: .orange,
                                  title: "Pin & Expand",
                                  subtitle: "Hover to peek, click to pin")
                        
                        featureRow(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", color: .purple,
                                  title: "Searchable History",
                                  subtitle: "Last 50 pastes")
                        
                        featureRow(icon: "lock.shield.fill", color: .green,
                                  title: "Private & Encrypted",
                                  subtitle: "AES-256 local storage")
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, Pasty.Spacing.md)
                    
                    // Hotkey Customization
                    hotkeySelectionSection
                        .padding(.horizontal, Pasty.Spacing.md)
                    
                    // Accessibility & Desktop side-by-side
                    HStack(alignment: .top, spacing: Pasty.Spacing.md) {
                        accessibilitySection
                        desktopAccessSection
                    }
                    .padding(.horizontal, Pasty.Spacing.md)
                    
                    // Encryption section (optional, below permissions)
                    encryptionSection
                        .padding(.horizontal, Pasty.Spacing.md)
                }
                .padding(.horizontal, Pasty.Spacing.md)
                .padding(.bottom, Pasty.Spacing.md)
            } // ScrollView
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        hasScrolled = true
                    }
                }
            }
            
            // Bottom bar
            bottomBar
        }
        .frame(width: 640, height: 820)
        .overlay(alignment: .bottomTrailing) {
            if !hasScrolled {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.purple)
                    .shadow(color: .purple.opacity(0.6), radius: 8)
                    .shadow(color: .purple.opacity(0.3), radius: 16)
                    .offset(y: scrollChevronBounce ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: scrollChevronBounce
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    .padding(.trailing, 20)
                    .padding(.bottom, 60)
                    .onAppear { scrollChevronBounce = true }
            }
        }
        .background(.ultraThinMaterial)
        .onReceive(timer) { _ in
            let granted = AXIsProcessTrusted()
            if granted != accessibilityGranted {
                withAnimation(Pasty.Motion.spring) {
                    accessibilityGranted = granted
                }
            }
            // Check Desktop access by trying to read the screenshot directory
            let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            let canAccess = FileManager.default.isReadableFile(atPath: desktopURL.path)
            if canAccess != desktopAccessGranted {
                withAnimation(Pasty.Motion.spring) {
                    desktopAccessGranted = canAccess
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
                
                Text("Accessibility — Hotkey & Screenshots")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            
            if accessibilityGranted {
                VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Pasty.Colors.success)
                            .font(.system(size: 13))
                        Text("Accessibility permission granted — you're all set!")
                            .font(.system(size: 13))
                            .foregroundStyle(Pasty.Colors.success)
                    }
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 12))
                        Text("⌘⇧3/4 screenshots will appear in Pasty instantly")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Pasty.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Pasty.Colors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                    let selectedTitle = GlobalHotkey(rawValue: globalHotkey)?.title ?? "⌘ ⇧ V"
                    Text("Pasty needs Accessibility access for two features:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    
                    // What it enables
                    VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                        explanationRow(icon: "keyboard.fill", color: .blue,
                                      text: "\(selectedTitle) global hotkey from any app")
                        explanationRow(icon: "camera.viewfinder", color: .cyan,
                                      text: "Instant ⌘⇧3/4 screenshot capture")
                        explanationRow(icon: "eye.slash.fill", color: .green,
                                      text: "Cannot read what you type — only shortcuts")
                        explanationRow(icon: "lock.fill", color: .purple,
                                      text: "No other permissions required")
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
    
    // MARK: - Desktop Access Section
    
    private var desktopAccessSection: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            HStack(spacing: Pasty.Spacing.sm) {
                Image(systemName: desktopAccessGranted ? "checkmark.circle.fill" : "folder.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(desktopAccessGranted ? Pasty.Colors.success : .cyan)
                
                Text("Desktop Files — Recording Previews")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            
            if desktopAccessGranted {
                VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Pasty.Colors.success)
                            .font(.system(size: 13))
                        Text("Desktop access granted — recording previews enabled!")
                            .font(.system(size: 13))
                            .foregroundStyle(Pasty.Colors.success)
                    }
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "film")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 12))
                        Text("Screen recordings will show thumbnails in your history")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Pasty.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Pasty.Colors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                    Text("Pasty needs Desktop access for one feature:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    
                    VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                        explanationRow(icon: "film", color: .cyan,
                                      text: "Screen recording thumbnail previews")
                        explanationRow(icon: "eye.slash.fill", color: .green,
                                      text: "Only reads screenshot & recording files")
                        explanationRow(icon: "clock.fill", color: .orange,
                                      text: "Recordings appear in history when saved")
                    }
                    .padding(Pasty.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .fill(.white.opacity(isHoveringDesktop ? 0.08 : 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isHoveringDesktop ? 0.8 : 0.5),
                                        .white.opacity(isHoveringDesktop ? 0.2 : 0.1),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isHoveringDesktop ? 2.0 : 1.5
                            )
                    )
                    .shadow(color: .black.opacity(isHoveringDesktop ? 0.3 : 0.2), radius: isHoveringDesktop ? 12 : 8, y: isHoveringDesktop ? 6 : 4)
                    .scaleEffect(isHoveringDesktop ? 1.01 : 1.0)
                    .onHover { isHoveringDesktop = $0 }
                    .animation(Pasty.Motion.spring, value: isHoveringDesktop)
                    
                    // Trigger Desktop permission
                    Button {
                        // Read a file from Desktop to trigger the TCC prompt
                        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                        _ = try? FileManager.default.contentsOfDirectory(atPath: desktopURL.path)
                    } label: {
                        HStack(spacing: Pasty.Spacing.sm) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Grant Desktop Access")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Pasty.Spacing.sm)
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: Pasty.Radius.sm, isPrimary: true))
                    
                    Text("You can skip this — recordings will still appear but without thumbnails.")
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
                    (desktopAccessGranted ? Pasty.Colors.success : Color.cyan).opacity(0.3),
                    lineWidth: Pasty.Glass.strokeWidth
                )
        )
        .animation(Pasty.Motion.spring, value: desktopAccessGranted)
    }
    
    // MARK: - Encryption Section
    
    private var encryptionSection: some View {
        VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
            HStack(spacing: Pasty.Spacing.sm) {
                Image(systemName: secureHistory ? "lock.shield.fill" : "lock.open.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(secureHistory ? Pasty.Colors.success : .purple)
                
                Text("Encrypted History")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                Spacer()
                
                Text("Optional")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.3), in: Capsule())
            }
            
            VStack(alignment: .leading, spacing: Pasty.Spacing.md) {
                Text("Encrypt your clipboard history with AES-256 so even if someone accesses your Mac, your paste data stays private.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                
                VStack(alignment: .leading, spacing: Pasty.Spacing.sm) {
                    explanationRow(icon: "shield.lefthalf.filled", color: .purple,
                                  text: "AES-256 encryption — military grade")
                    explanationRow(icon: "key.fill", color: .orange,
                                  text: "Key stored securely in macOS Keychain")
                    explanationRow(icon: "eye.slash.fill", color: .green,
                                  text: "Only text is encrypted — images stay fast")
                }
                .padding(Pasty.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                
                // Toggle
                Toggle(isOn: Binding(
                    get: { secureHistory },
                    set: { newValue in
                        withAnimation(Pasty.Motion.spring) {
                            secureHistory = newValue
                            if newValue {
                                showKeychainNote = true
                                // Immediately trigger Keychain access to create/fetch the key
                                // This prompts the user for Keychain permission NOW, not later
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let _ = try? EncryptionService.shared.encrypt("keychain-init")
                                    DispatchQueue.main.async {
                                        withAnimation(Pasty.Motion.spring) {
                                            showKeychainNote = false
                                            encryptionConfirmed = true
                                        }
                                    }
                                }
                            } else {
                                showKeychainNote = false
                                encryptionConfirmed = false
                            }
                        }
                    }
                )) {
                    Text("Enable encrypted history")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.switch)
                .tint(.purple)
                
                // Keychain explanation — shows briefly while waiting for Keychain prompt
                if showKeychainNote && !encryptionConfirmed {
                    HStack(alignment: .top, spacing: Pasty.Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        
                        Text("macOS may ask to allow Keychain access — tap **Always Allow** so Pasty can encrypt without asking again.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(Pasty.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                            .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)))
                }
                
                // Confirmed state — shows green checkmark after Keychain is set up
                if encryptionConfirmed {
                    HStack(spacing: Pasty.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Pasty.Colors.success)
                            .font(.system(size: 13))
                        Text("Encryption enabled — your clipboard history is now encrypted with AES-256.")
                            .font(.system(size: 12))
                            .foregroundStyle(Pasty.Colors.success)
                            .lineSpacing(2)
                    }
                    .padding(Pasty.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Pasty.Colors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                if !secureHistory {
                    Text("You can always enable this later in Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(Pasty.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Pasty.Radius.md, style: .continuous)
                .strokeBorder(
                    (secureHistory ? Pasty.Colors.success : Color.purple).opacity(0.3),
                    lineWidth: Pasty.Glass.strokeWidth
                )
        )
        .animation(Pasty.Motion.spring, value: secureHistory)
        .animation(Pasty.Motion.spring, value: showKeychainNote)
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
                    .onChange(of: globalHotkey) {
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
        HStack(spacing: Pasty.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
