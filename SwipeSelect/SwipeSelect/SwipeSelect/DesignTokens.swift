import SwiftUI

// MARK: - Design Tokens (Matching Pasty's Design Language)

enum Glide {
    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // MARK: Glass
    enum Glass {
        static let strokeWidth: CGFloat = 0.5
        static let strokeOpacity: Double = 0.2
        static let shadowRadius: CGFloat = 12
        static let shadowOpacity: Double = 0.08
    }
    
    // MARK: Animation
    enum Motion {
        static let spring = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.1)
        static let quickSpring = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.86, blendDuration: 0.05)
    }
    
    // MARK: Typography
    enum Typography {
        static let title = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 14, weight: .medium, design: .rounded)
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: Semantic Colors
    enum Colors {
        static let primary = Color.accentColor
        static let glass = Color.white.opacity(0.07)
        static let glassStroke = Color.white.opacity(Glass.strokeOpacity)
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
    }
}
