import SwiftUI

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = Pasty.Radius.lg
    var material: Material = .ultraThinMaterial
    
    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Pasty.Glass.strokeWidth
                    )
            )
            .shadow(color: .black.opacity(Pasty.Glass.shadowOpacity), radius: Pasty.Glass.shadowRadius, y: 4)
    }
}

// MARK: - Glass Card Modifier (elevated variant for hover previews)

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Pasty.Radius.md
    var isHovered: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.0))
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(Pasty.Motion.spring, value: isHovered)
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Pasty.Radius.sm
    var isPrimary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Pasty.Typography.headline)
            .padding(.horizontal, Pasty.Spacing.lg)
            .padding(.vertical, Pasty.Spacing.sm)
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.85),
                                    Color.accentColor.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: Pasty.Glass.strokeWidth)
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Pasty.Colors.glassStroke, lineWidth: Pasty.Glass.strokeWidth)
                        )
                }
            }
            .foregroundStyle(isPrimary ? .white : .primary)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Pasty.Motion.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Glass Text Field Style

struct GlassTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(Pasty.Typography.body)
            .padding(Pasty.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Pasty.Radius.sm, style: .continuous)
                    .strokeBorder(Pasty.Colors.glassStroke, lineWidth: Pasty.Glass.strokeWidth)
            )
    }
}

// MARK: - Glass Segmented Control

struct GlassTabBar: View {
    @Binding var selection: PastyTab
    @Namespace private var glassBubble
    @State private var hovered: PastyTab?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PastyTab.allCases) { tab in
                let isSelected = selection == tab
                let isHovered = hovered == tab
                
                VStack(spacing: 3) {
                    ZStack {
                        // Sliding glass magnifier bubble — only behind selected tab
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    ZStack {
                                        // Inner glass refraction
                                        Capsule(style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.22),
                                                        Color.white.opacity(0.04),
                                                        Color.white.opacity(0.10)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        // Top highlight shimmer
                                        Capsule(style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.30), .clear],
                                                    startPoint: .top,
                                                    endPoint: .center
                                                )
                                            )
                                        
                                        // Glass border
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.45),
                                                        Color.white.opacity(0.10),
                                                        Color.white.opacity(0.25)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.7
                                            )
                                    }
                                }
                                .shadow(color: .white.opacity(0.08), radius: 1, y: -0.5)
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                                .frame(height: 32)
                                .matchedGeometryEffect(id: "glassBubble", in: glassBubble)
                        }
                        
                        // Icon — scales up when selected (magnified)
                        HStack(spacing: 5) {
                            Image(systemName: isSelected ? tab.symbolFill : tab.symbol)
                                .font(.system(
                                    size: isSelected ? 14 : 12,
                                    weight: isSelected ? .bold : .medium
                                ))
                                .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))
                            
                            Text(tab.rawValue)
                                .font(.system(
                                    size: isSelected ? 11 : 10,
                                    weight: isSelected ? .bold : .medium,
                                    design: .rounded
                                ))
                        }
                        .frame(height: 32)
                    }
                }
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .opacity(isSelected ? 1.0 : (isHovered ? 0.9 : 0.7))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        selection = tab
                    }
                }
                .onHover { hovering in
                    withAnimation(Pasty.Motion.quickSpring) {
                        hovered = hovering ? tab : nil
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.03))
                
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground(cornerRadius: CGFloat = Pasty.Radius.lg) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
    
    func glassCard(cornerRadius: CGFloat = Pasty.Radius.md, isHovered: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, isHovered: isHovered))
    }
    
    func glassTextField() -> some View {
        modifier(GlassTextFieldModifier())
    }
}
