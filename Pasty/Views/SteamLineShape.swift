import SwiftUI

/// A wiggly steam line that animates based on a phase value
struct SteamLine: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let amplitude: CGFloat = rect.width * 0.5
        
        path.move(to: CGPoint(x: midX, y: rect.maxY))
        
        // Full 2π sine cycle so linear animation loops perfectly
        let steps = 16
        for i in 0...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let y = rect.maxY - (progress * rect.height)
            let sway = sin(progress * .pi * 3 + phase * .pi * 2) * amplitude * progress
            path.addLine(to: CGPoint(x: midX + sway, y: y))
        }
        
        return path
    }
}
