import SwiftUI
import AppKit

/// Adds invisible edge/corner drag zones around a view for resize.
/// Corners extend slightly outside for easy grabbing. Edge zones avoid corners.
struct EdgeResizable: ViewModifier {
    @Binding var width: Double
    @Binding var height: Double
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    
    @State private var liveWidth: Double = 0
    @State private var liveHeight: Double = 0
    @State private var isDragging = false
    @State private var startW: Double = 0
    @State private var startH: Double = 0
    @State private var startMousePos: NSPoint = .zero
    
    private var effectiveWidth: Double { isDragging ? liveWidth : width }
    private var effectiveHeight: Double { isDragging ? liveHeight : height }
    
    // Corner zones are large and extend well outside the view
    private let cornerInset: CGFloat = 40   // how far inward from corner
    private let cornerOutset: CGFloat = 24  // how far outside the view
    // Edge zones are inset from corners to avoid overlap
    private let edgeThickness: CGFloat = 14
    
    func body(content: Content) -> some View {
        content
            .frame(width: effectiveWidth, height: effectiveHeight)
            .overlay { edgeZones }
            .overlay { cornerZones }
            .onAppear {
                liveWidth = width
                liveHeight = height
            }
            .onChange(of: width) { _, nv in if !isDragging { liveWidth = nv } }
            .onChange(of: height) { _, nv in if !isDragging { liveHeight = nv } }
    }
    
    // MARK: - Corner Zones (extend outside view bounds)
    
    private var cornerZones: some View {
        let size = cornerInset + cornerOutset
        return ZStack {
            // Bottom-right
            cornerHitArea(xDir: 1, yDir: 1)
                .frame(width: size, height: size)
                .offset(x: cornerOutset / 2, y: cornerOutset / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            // Bottom-left
            cornerHitArea(xDir: -1, yDir: 1)
                .frame(width: size, height: size)
                .offset(x: -cornerOutset / 2, y: cornerOutset / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            // Top-right
            cornerHitArea(xDir: 1, yDir: -1)
                .frame(width: size, height: size)
                .offset(x: cornerOutset / 2, y: -cornerOutset / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // Top-left
            cornerHitArea(xDir: -1, yDir: -1)
                .frame(width: size, height: size)
                .offset(x: -cornerOutset / 2, y: -cornerOutset / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private func cornerHitArea(xDir: CGFloat, yDir: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onHover { h in
                if h { NSCursor.crosshair.push() } else { NSCursor.pop() }
            }
            .gesture(resizeGesture(xDir: xDir, yDir: yDir))
    }
    
    // MARK: - Edge Zones (inset from corners to avoid overlap)
    
    private var edgeZones: some View {
        let inset = cornerInset + 4 // extra gap so edges don't fight corners
        return ZStack {
            // Right edge — full height minus corner areas
            Color.clear
                .frame(width: edgeThickness)
                .padding(.vertical, inset)
                .contentShape(Rectangle())
                .onHover { h in if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(xDir: 1, yDir: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            // Left edge
            Color.clear
                .frame(width: edgeThickness)
                .padding(.vertical, inset)
                .contentShape(Rectangle())
                .onHover { h in if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(xDir: -1, yDir: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            // Bottom edge
            Color.clear
                .frame(height: edgeThickness)
                .padding(.horizontal, inset)
                .contentShape(Rectangle())
                .onHover { h in if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(xDir: 0, yDir: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // Top edge
            Color.clear
                .frame(height: edgeThickness)
                .padding(.horizontal, inset)
                .contentShape(Rectangle())
                .onHover { h in if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(xDir: 0, yDir: -1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // MARK: - Shared Resize Gesture
    
    private func resizeGesture(xDir: CGFloat, yDir: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    startW = liveWidth
                    startH = liveHeight
                    startMousePos = NSPoint(x: value.startLocation.x, y: value.startLocation.y)
                    isDragging = true
                }
                let dx = value.location.x - startMousePos.x
                let dy = value.location.y - startMousePos.y
                if xDir != 0 { liveWidth = clampW(startW + dx * xDir) }
                if yDir != 0 { liveHeight = clampH(startH + dy * yDir) }
            }
            .onEnded { _ in commitDrag() }
    }
    
    // MARK: - Helpers
    
    private func clampW(_ v: Double) -> Double { max(Double(minWidth), min(Double(maxWidth), v)) }
    private func clampH(_ v: Double) -> Double { max(Double(minHeight), min(Double(maxHeight), v)) }
    
    private func commitDrag() {
        width = liveWidth
        height = liveHeight
        isDragging = false
    }
}

extension View {
    func edgeResizable(
        width: Binding<Double>,
        height: Binding<Double>,
        minWidth: CGFloat = 320,
        maxWidth: CGFloat = 900,
        minHeight: CGFloat = 300,
        maxHeight: CGFloat = 1200
    ) -> some View {
        modifier(EdgeResizable(
            width: width,
            height: height,
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            maxHeight: maxHeight
        ))
    }
}
