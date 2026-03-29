import Cocoa
import QuartzCore

/// Floating overlay that shows a faded text-caret line during glide.
/// On release, the caret pops (scale bounce) before disappearing.
final class CursorOverlay {
    static let shared = CursorOverlay()
    
    private var overlayWindow: NSWindow?
    private var caretLayer: CALayer?
    private let caretWidth: CGFloat = 2.5
    private let caretHeight: CGFloat = 20
    private let windowSize: CGFloat = 30
    
    private init() {}
    
    // MARK: - Show (glide start)
    
    func show(at screenPoint: CGPoint) {
        if overlayWindow == nil {
            createOverlayWindow()
        }
        
        guard let window = overlayWindow, let layer = caretLayer else { return }
        
        positionWindow(window, at: screenPoint)
        window.orderFrontRegardless()
        
        // Fade the system cursor
        NSCursor.hide()
        
        // Show faded caret line
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        layer.opacity = 0.35
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }
    
    // MARK: - Move (during glide)
    
    func move(to screenPoint: CGPoint) {
        guard let window = overlayWindow else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        positionWindow(window, at: screenPoint)
        CATransaction.commit()
    }
    
    // MARK: - Pop & Hide (glide end)
    
    func popAndHide(at screenPoint: CGPoint) {
        guard let layer = caretLayer, let window = overlayWindow else {
            NSCursor.unhide()
            return
        }
        
        positionWindow(window, at: screenPoint)
        
        // Pop: scale Y (stretch tall), brighten, then fade
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 1.6, 1.0]
        pop.keyTimes = [0, 0.35, 1.0]
        pop.duration = 0.3
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        
        // Brief flash to full opacity then fade
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.35, 0.9, 0.0]
        flash.keyTimes = [0, 0.25, 1.0]
        flash.duration = 0.3
        
        let group = CAAnimationGroup()
        group.animations = [pop, flash]
        group.duration = 0.3
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            window.orderOut(nil)
            layer.removeAllAnimations()
            layer.opacity = 0
            NSCursor.unhide()
        }
        layer.add(group, forKey: "popAndFade")
        CATransaction.commit()
    }
    
    // MARK: - Instant Hide
    
    func hide() {
        overlayWindow?.orderOut(nil)
        caretLayer?.removeAllAnimations()
        NSCursor.unhide()
    }
    
    // MARK: - Setup
    
    private func createOverlayWindow() {
        let frame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let hostView = NSView(frame: frame)
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = CGColor.clear
        window.contentView = hostView
        
        // Blue text caret line
        let caret = CALayer()
        caret.frame = CGRect(
            x: (windowSize - caretWidth) / 2,
            y: (windowSize - caretHeight) / 2,
            width: caretWidth,
            height: caretHeight
        )
        caret.backgroundColor = NSColor.controlAccentColor.cgColor
        caret.cornerRadius = caretWidth / 2
        caret.shadowColor = NSColor.controlAccentColor.cgColor
        caret.shadowRadius = 4
        caret.shadowOpacity = 0.6
        caret.shadowOffset = .zero
        caret.opacity = 0
        
        hostView.layer?.addSublayer(caret)
        
        self.caretLayer = caret
        self.overlayWindow = window
    }
    
    private func positionWindow(_ window: NSWindow, at screenPoint: CGPoint) {
        let origin = NSPoint(
            x: screenPoint.x - windowSize / 2,
            y: screenFlippedY(screenPoint.y) - windowSize / 2
        )
        window.setFrameOrigin(origin)
    }
    
    /// CGEvent Y (top-left origin) → NSWindow Y (bottom-left origin)
    private func screenFlippedY(_ y: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main else { return y }
        return screen.frame.height - y
    }
}
