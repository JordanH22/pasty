import SwiftUI

struct MenuBarPanel: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var axManager = AccessibilityManager.shared
    @State private var showTuning = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Compact Header ──
            HStack(spacing: 10) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("SwipeSelect")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                
                Spacer()
                
                // Liquid glass pill toggle
                Toggle("", isOn: $prefs.engineEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .onChange(of: prefs.engineEnabled) { _, on in
                        if on { GlideEngine.shared.start() }
                        else { GlideEngine.shared.stop() }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().opacity(0.08)
            
            // ── Mode Selector ──
            HStack(spacing: 6) {
                modePill("Free Glide", icon: "hand.draw", tag: "freeGlide")
                modePill("OG Mode", icon: "arrow.left.arrow.right", tag: "ogSwipeSelection")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider().opacity(0.08)
            
            // ── Feature Pills ──
            VStack(spacing: 6) {
                featureRow(isOn: $prefs.doubleTapSelectEnabled,
                          icon: "hand.tap.fill", color: .orange,
                          title: "Double-Tap Select")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // ── Tuning (collapsible) ──
            Divider().opacity(0.08)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showTuning.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("Tuning")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(showTuning ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showTuning {
                VStack(spacing: 8) {
                    miniSlider("Speed", value: $prefs.glideSpeed, range: 0.1...8, step: 0.1,
                              display: String(format: "%.1f×", prefs.glideSpeed))
                    miniSlider("Sensitivity", value: $prefs.ogSensitivity, range: 0.5...40, step: 0.5,
                              display: String(format: "%.1f", prefs.ogSensitivity))
                    miniSlider("Release", value: $prefs.glideEndDelay, range: 0.05...1.2, step: 0.05,
                              display: "\(Int(prefs.glideEndDelay * 1000))ms")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // ── Accessibility Warning ──
            if !axManager.isTrusted {
                Divider().opacity(0.08)
                Button {
                    AccessibilityManager.shared.promptAndOpen()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Grant Accessibility")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            // ── Footer ──
            Divider().opacity(0.08)
            HStack {
                Text("v1.0")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
    }
    
    // MARK: - Mode Pill
    
    private func modePill(_ title: String, icon: String, tag: String) -> some View {
        let selected = prefs.cursorMode == tag
        return Button {
            prefs.cursorMode = tag
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .foregroundStyle(selected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Feature Row
    
    private func featureRow(isOn: Binding<Bool>, icon: String, color: Color, title: String) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }
    
    // MARK: - Mini Slider
    
    private func miniSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, display: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(display)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.mini)
        }
    }
}
