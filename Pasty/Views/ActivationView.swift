import SwiftUI

struct ActivationView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseKey: String = ""
    @State private var isVerifying = false
    @State private var showError = false
    @State private var errorMsg = ""
    
    // Aesthetic Animation States
    @State private var breathing = false
    @State private var hackerMode = false
    @State private var shakeOffset: CGFloat = 0
    @State private var steamPhase: CGFloat = 0
    @State private var bounceOffset: CGFloat = -4

    var body: some View {
        ZStack {
            // Minimalist Native Background (Flashing Red only for Security Overrides)
            Group {
                if hackerMode {
                    Color.red.opacity(0.2)
                        .ignoresSafeArea()
                } else {
                    Color.clear
                        .ignoresSafeArea()
                }
            }
            .animation(.easeInOut, value: hackerMode)
            
            // Floating 3D Glass Pane
            VStack(spacing: 24) {
                // Custom macOS Red Exit Node
                HStack {
                    Button(action: { NSApp.terminate(nil) }) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.36, blue: 0.33))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, -4)
                .padding(.top, -10)
                .padding(.bottom, -30)
                
                // Header
                VStack(spacing: 8) {
                    // Animated Bouncing Pasty Mascot
                    ZStack(alignment: .top) {
                        // Wiggly steam lines
                        ForEach(0..<3, id: \.self) { index in
                            SteamLine(phase: steamPhase + Double(index) * 0.8)
                                .stroke(
                                    hackerMode ? Color.red.opacity(0.6 - Double(index) * 0.1) : Color.white.opacity(0.45 - Double(index) * 0.08),
                                    lineWidth: 2.0
                                )
                                .frame(width: 14, height: 18)
                                .offset(
                                    x: CGFloat(index - 1) * 8,
                                    y: -8
                                )
                        }
                        
                        PastyIconView()
                            .frame(width: 48, height: 40)
                            .offset(y: 12 + bounceOffset)
                    }
                    .frame(width: 52, height: 64)
                    .onAppear {
                        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                            steamPhase = 1.0
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            bounceOffset = 4
                        }
                    }
                    .shadow(color: hackerMode ? .red : .clear, radius: 10)
                    .padding(.bottom, 6)
                    
                    Text(hackerMode ? "SECURITY OVERRIDE" : "Activate Pasty")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text(hackerMode ? "PENTESTER MODE INITIATED" : "Enter your Lemon Squeezy license key to unlock.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)
                
                // Serial Input Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("LICENSE KEY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(hackerMode ? Color.red : Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: isVerifying ? .blue.opacity(0.3) : .clear, radius: 10)
                        .offset(x: shakeOffset)
                        .onChange(of: licenseKey) { newValue in
                            let lower = newValue.lowercased()
                            if lower.contains("crack") || lower.contains("bypass") || lower.contains("admin") {
                                withAnimation(.spring()) { hackerMode = true }
                                triggerShake()
                            } else {
                                withAnimation(.spring()) { hackerMode = false }
                            }
                        }
                        .onSubmit {
                            Task { await verifyLicense() }
                        }
                }
                
                if showError {
                    Text(errorMsg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hackerMode ? .white : .red)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background((hackerMode ? Color.red : Color.red.opacity(0.1)).cornerRadius(6))
                }
                
                // Unlock Button
                Button(action: {
                    Task { await verifyLicense() }
                }) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text(isVerifying ? "Verifying..." : "Unlock Pasty")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hackerMode ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: (hackerMode ? Color.red : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isVerifying || licenseKey.isEmpty)
                
                // Support & Checkout Links
                HStack(spacing: 16) {
                    Link("Lost your license key?", destination: URL(string: "https://pasty.dev")!)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("•").foregroundColor(.secondary.opacity(0.5)).font(.system(size: 10))
                    
                    Link("Buy Pasty for $9.99", destination: URL(string: "https://pasty.dev/#pricing")!)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(NSColor.systemBlue))
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85)) // Less transparent
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            .padding(40)
        }
        .frame(width: 480, height: 520)
        // Disabling explicit size modifications so it natively binds to NSWindow boundaries
    }
    
    private func verifyLicense() async {
        isVerifying = true
        showError = false
        errorMsg = ""
        
        // Wait a small buffer to show the UX is 'working' cryptographically
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        do {
            let success = try await licenseManager.validateKey(licenseKey)
            if success {
                // isActivated is now true — close this window.
                // windowWillClose in AppDelegate sees isActivated=true and sets
                // activation policy to .accessory (no Terminate).
                NSApp.keyWindow?.close()
            } else {
                throw NSError(domain: "Invalid License", code: 401)
            }
        } catch {
            showError = true
            errorMsg = hackerMode ? "CRITICAL: UNAUTHORIZED OVERRIDE DETECTED." : "Invalid or expired license key."
            triggerShake()
        }
        
        isVerifying = false
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.default) { shakeOffset = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.default) { shakeOffset = -10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.default) { shakeOffset = 0 }
                }
            }
        }
    }
}
