import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: PastyTab = .history
    
    var body: some View {
        // Single pill — header + content integrated like CC modules
        VStack(spacing: 0) {
            header
            
            // Tab Content
            Group {
                switch selectedTab {
                case .newPaste:
                    NewPasteView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: selectedTab == .newPaste ? .leading : .trailing)),
                removal: .opacity
            ))
            .animation(Pasty.Motion.spring, value: selectedTab)
        }
        .background {
            glassPill(cornerRadius: 18)
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
        .padding(8)
        .edgeResizable(
            width: Bindable(appState).popoverWidth,
            height: Bindable(appState).popoverHeight,
            minWidth: 320, maxWidth: 900,
            minHeight: 350, maxHeight: 800
        )
    }
    
    // MARK: - Glass Pill Background
    
    private func glassPill(cornerRadius: CGFloat) -> some View {
        ZStack {
            // Dark backing layer for readability on light backgrounds
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.65))
            
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.05))
        }
    }
    
    // MARK: - Header
    
    @State private var steamPhase: CGFloat = 0
    
    private var header: some View {
        VStack(spacing: Pasty.Spacing.md) {
            HStack {
                // App icon + title
                HStack(spacing: Pasty.Spacing.sm) {
                    // Pasty icon with steam lines
                    ZStack(alignment: .top) {
                        // 3 wiggly steam lines
                        ForEach(0..<3, id: \.self) { index in
                            SteamLine(phase: steamPhase + Double(index) * 0.8)
                                .stroke(
                                    Color.white.opacity(0.35 - Double(index) * 0.08),
                                    lineWidth: 1.2
                                )
                                .frame(width: 8, height: 10)
                                .offset(
                                    x: CGFloat(index - 1) * 5,
                                    y: -3
                                )
                        }
                        
                        PastyIconView()
                            .frame(width: 24, height: 20)
                            .offset(y: 7)
                    }
                    .frame(width: 26, height: 28)
                    .onAppear {
                        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                            steamPhase = 1.0
                        }
                    }
                    
                    Text("Pasty")
                        .font(Pasty.Typography.title)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: Pasty.Spacing.sm) {
                    if !appState.isOnline {
                        Label("Offline", systemImage: "wifi.slash")
                            .font(Pasty.Typography.caption)
                            .foregroundStyle(Pasty.Colors.warning)
                            .padding(.horizontal, Pasty.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(Pasty.Colors.warning.opacity(0.12), in: Capsule())
                    }
                    
                    if appState.pendingUploadCount > 0 {
                        Label("\(appState.pendingUploadCount)", systemImage: "arrow.clockwise.icloud")
                            .font(Pasty.Typography.caption)
                            .foregroundStyle(Pasty.Colors.queued)
                            .padding(.horizontal, Pasty.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(Pasty.Colors.queued.opacity(0.12), in: Capsule())
                }
                }
            }
            
            // Tab bar
            GlassTabBar(selection: $selectedTab)
        }
        .padding(.horizontal, Pasty.Spacing.lg)
        .padding(.top, Pasty.Spacing.lg)
        .padding(.bottom, Pasty.Spacing.md)
    }
}

#Preview {
    PopoverView()
        .environment(AppState())
        .modelContainer(for: PasteItem.self, inMemory: true)
}
