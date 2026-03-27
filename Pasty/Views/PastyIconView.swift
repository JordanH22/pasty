import SwiftUI

/// A cute little Cornish pasty icon drawn in SwiftUI
struct PastyIconView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            // Golden-brown pasty body
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: w * 0.08, y: h * 0.55))
            bodyPath.addQuadCurve(
                to: CGPoint(x: w * 0.92, y: h * 0.55),
                control: CGPoint(x: w * 0.5, y: h * 1.15)
            )
            bodyPath.addQuadCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.55),
                control: CGPoint(x: w * 0.5, y: -h * 0.1)
            )
            bodyPath.closeSubpath()
            
            // Fill with warm golden gradient
            context.fill(bodyPath, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.92, green: 0.72, blue: 0.40),
                    Color(red: 0.82, green: 0.58, blue: 0.30)
                ]),
                startPoint: .init(x: w * 0.5, y: 0),
                endPoint: .init(x: w * 0.5, y: h)
            ))
            
            // Body outline
            context.stroke(bodyPath, with: .color(Color(red: 0.60, green: 0.40, blue: 0.20)), lineWidth: 0.8)
            
            // Crimped edge — little bumps along the curved top
            let crimpY = h * 0.38
            let crimpPoints: [(CGFloat, CGFloat)] = [
                (0.22, 0.0), (0.34, -0.04), (0.46, -0.06),
                (0.58, -0.06), (0.70, -0.04), (0.82, 0.0)
            ]
            
            for (xRatio, yOffset) in crimpPoints {
                var crimp = Path()
                let cx = w * xRatio
                let cy = crimpY + h * yOffset
                crimp.addEllipse(in: CGRect(x: cx - 1.5, y: cy - 1, width: 3, height: 2.5))
                context.fill(crimp, with: .color(Color(red: 0.78, green: 0.55, blue: 0.28)))
            }
            
            // Little cute face — dots for eyes
            let eyeY = h * 0.52
            var leftEye = Path()
            leftEye.addEllipse(in: CGRect(x: w * 0.36, y: eyeY, width: 2, height: 2))
            context.fill(leftEye, with: .color(Color(red: 0.25, green: 0.18, blue: 0.12)))
            
            var rightEye = Path()
            rightEye.addEllipse(in: CGRect(x: w * 0.58, y: eyeY, width: 2, height: 2))
            context.fill(rightEye, with: .color(Color(red: 0.25, green: 0.18, blue: 0.12)))
            
            // Little smile
            var smile = Path()
            smile.move(to: CGPoint(x: w * 0.42, y: h * 0.62))
            smile.addQuadCurve(
                to: CGPoint(x: w * 0.58, y: h * 0.62),
                control: CGPoint(x: w * 0.5, y: h * 0.70)
            )
            context.stroke(smile, with: .color(Color(red: 0.25, green: 0.18, blue: 0.12)), lineWidth: 0.8)
            
            // Rosy cheeks
            var leftCheek = Path()
            leftCheek.addEllipse(in: CGRect(x: w * 0.26, y: h * 0.56, width: 3, height: 2.5))
            context.fill(leftCheek, with: .color(Color.pink.opacity(0.35)))
            
            var rightCheek = Path()
            rightCheek.addEllipse(in: CGRect(x: w * 0.66, y: h * 0.56, width: 3, height: 2.5))
            context.fill(rightCheek, with: .color(Color.pink.opacity(0.35)))
        }
    }
}
