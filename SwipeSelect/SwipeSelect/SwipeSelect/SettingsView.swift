import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var axManager = AccessibilityManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Glide.Spacing.md) {
            // Engine toggle
            Toggle("Enable SwipeSelect Engine", isOn: $prefs.engineEnabled)
                .onChange(of: prefs.engineEnabled) { _, newValue in
                    if newValue { GlideEngine.shared.start() }
                    else { GlideEngine.shared.stop() }
                }
            
            Divider().opacity(0.15)
            
            // Mode picker
            Picker("Cursor Mode", selection: $prefs.cursorMode) {
                Text("Free Glide").tag("freeGlide")
                Text("OG Mode").tag("ogSwipeSelection")
            }
            .pickerStyle(.segmented)
            
            Divider().opacity(0.15)
            
            // Pure trackpad features
            Toggle("Double-Tap Select", isOn: $prefs.doubleTapSelectEnabled)
            
            Divider().opacity(0.15)
            
            // Sensitivity
            if prefs.cursorMode == "freeGlide" {
                VStack(alignment: .leading, spacing: Glide.Spacing.xs) {
                    HStack {
                        Text("Glide Speed (Multiplier)")
                        Spacer()
                        Text(String(format: "%.1f×", prefs.glideSpeed))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    // Widened range: 0.1 is extremely slow (insensitive), 12.0 is wildly fast
                    Slider(value: $prefs.glideSpeed, in: 0.1...12.0, step: 0.1)
                }
            } else {
                VStack(alignment: .leading, spacing: Glide.Spacing.xs) {
                    HStack {
                        Text("Swipe Resistance")
                        Spacer()
                        Text(String(format: "%.1f", prefs.ogSensitivity))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    // Widened range: 0.5 is insanely fast, 25.0 is incredibly slow
                    Slider(value: $prefs.ogSensitivity, in: 0.5...25.0, step: 0.5)
                }
            }
            
            VStack(alignment: .leading, spacing: Glide.Spacing.xs) {
                HStack {
                    Text("Release Delay")
                    Spacer()
                    Text(String(format: "%.0fms", prefs.glideEndDelay * 1000))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $prefs.glideEndDelay, in: 0.05...1.5, step: 0.05)
            }
            
            Divider().opacity(0.15)
            
            launchAtLoginToggle
            
            if !axManager.isTrusted {
                Button("Grant Accessibility") {
                    AccessibilityManager.shared.promptAndOpen()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .font(Glide.Typography.body)
        .padding(Glide.Spacing.lg)
        .frame(width: 320)
    }
    
    private var launchAtLoginToggle: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch { }
            }
        ))
    }
}
