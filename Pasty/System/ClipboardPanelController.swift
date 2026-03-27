import SwiftUI
import AppKit

// MARK: - Shared Panel State (Observable)

@MainActor
@Observable
final class ClipboardPanelState {
    var selectedIndex: Int = 0
    var isKeyboardNavigating: Bool = false
    var items: [ClipboardHistory.ClipboardEntry] = []
    var appeared: Bool = false
    var lastPastedId: UUID? = nil
    var suppressHoverCollapse: Bool = false
    var hoverSelectionEnabled: Bool = false
    var onDismiss: () -> Void = {}
    var onPaste: ((ClipboardHistory.ClipboardEntry) -> Void)?
    
    func reload() {
        items = ClipboardHistory.shared.items
        selectedIndex = 0
        appeared = false
        hoverSelectionEnabled = false
    }
    
    func moveUp() {
        if selectedIndex > 0 { 
            isKeyboardNavigating = true
            selectedIndex -= 1 
        }
    }
    
    func moveDown() {
        if selectedIndex < items.count - 1 { 
            isKeyboardNavigating = true
            selectedIndex += 1 
        }
    }
    
    func pasteSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        onPaste?(items[selectedIndex])
    }
    
    func pasteItem(_ item: ClipboardHistory.ClipboardEntry) {
        // Automatically bounce the pasted item to the top of the history list
        ClipboardHistory.shared.bringToTop(item)
        items = ClipboardHistory.shared.items
        selectedIndex = 0
        
        // Pass the fresh new top item to the paste handler
        if let newItem = items.first {
            onPaste?(newItem)
        }
    }
    
    func removeSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        ClipboardHistory.shared.remove(items[selectedIndex])
        items = ClipboardHistory.shared.items
        if selectedIndex >= items.count {
            selectedIndex = max(0, items.count - 1)
        }
    }
    
    func handleKeyDown(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 126: // Up arrow
            moveUp()
            return true
        case 125: // Down arrow
            moveDown()
            return true
        case 36: // Return/Enter
            pasteSelected()
            return true
        case 51: // Delete/Backspace
            removeSelected()
            return true
        case 53: // Escape
            onDismiss()
            return true
        default:
            return false
        }
    }
}

// MARK: - Floating Panel Controller

@MainActor
final class ClipboardPanelController {
    static let shared = ClipboardPanelController()
    
    private var panel: KeyablePanel?
    private var hostingController: NSHostingController<AnyView>?
    private var previousApp: NSRunningApplication?
    private var globalEventMonitor: Any?
    private var localMouseMonitor: Any?
    let state = ClipboardPanelState()
    
    var isVisible: Bool { panel?.isVisible ?? false }
    var suppressDismiss = false
    
    private init() {
        state.onDismiss = { [weak self] in
            self?.dismiss()
        }
        state.onPaste = { [weak self] item in
            self?.dismissAndPaste(item)
        }
    }
    
    func toggle() {
        if isVisible {
            dismiss()
        } else {
            show()
        }
    }
    
    func show() {
        dismiss()
        
        // Remember which app was focused before we show the panel
        previousApp = NSWorkspace.shared.frontmostApplication
        
        // Wire live updates: when the clipboard daemon captures new content,
        // animate the new entry sliding into the panel's list in real-time
        ClipboardHistory.shared.onChange = { [weak self] in
            guard let self, self.isVisible else { return }
            let oldCount = self.state.items.count
            let newItems = ClipboardHistory.shared.items
            let inserted = newItems.count > oldCount
            
            // Suppress hover-exit collapse during physical row shifts
            if inserted {
                self.state.suppressHoverCollapse = true
            }
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.state.items = newItems
                if inserted {
                    self.state.selectedIndex += 1
                }
            }
            
            // Clear suppression after animation settles
            if inserted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.state.suppressHoverCollapse = false
                }
            }
        }
        
        // Reload state
        state.reload()
        
        // Setup global monitor for outside clicks
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        
        let appState = (NSApp.delegate as? AppDelegate)?.appState ?? AppState()
        let view = AnyView(ClipboardPanelView(state: state)
            .environment(appState))
        
        let hosting = NSHostingController(rootView: view)
        hosting.view.layer?.backgroundColor = .clear
        hosting.sizingOptions = [.intrinsicContentSize]
        
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentViewController = hosting
        panel.hidesOnDeactivate = false
        
        // Keyboard handler uses the shared observable state
        panel.keyHandler = { [weak self] event in
            self?.state.handleKeyDown(event) ?? false
        }
        
        // Position at mouse cursor using initial sizes
        let mouseLocation = NSEvent.mouseLocation
        let panelSize = NSSize(width: appState.hotkeyMenuWidth + 20, height: appState.hotkeyMenuHeight + 20)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main!
        
        var origin = NSPoint(
            x: mouseLocation.x - panelSize.width / 2,
            y: mouseLocation.y - panelSize.height - 8
        )
        
        let screenFrame = screen.visibleFrame
        origin.x = max(screenFrame.minX + 8, min(origin.x, screenFrame.maxX - panelSize.width - 8))
        origin.y = max(screenFrame.minY + 8, min(origin.y, screenFrame.maxY - panelSize.height - 8))
        
        // Use initial frame; intrinsic sizing will take over and auto-expand Live if they use sliders!
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        
        self.panel = panel
        self.hostingController = hosting
        
        // Liquid glass pop-out animation — scale from 0.85 with spring overshoot
        panel.alphaValue = 0
        
        // Set initial transform: scaled down from center
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            contentView.layer?.position = CGPoint(
                x: contentView.bounds.midX,
                y: contentView.bounds.midY
            )
            let scale = CATransform3DMakeScale(0.85, 0.85, 1)
            contentView.layer?.transform = scale
        }
        
        panel.makeKeyAndOrderFront(nil)
        
        // Scale + Opacity animation to full size
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.15) // Spring-like
            panel.animator().alphaValue = 1
            if let layer = panel.contentView?.layer {
                let scale = CASpringAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.85
                scale.toValue = 1.0
                scale.mass = 1.0
                scale.stiffness = 322
                scale.damping = 23
                scale.initialVelocity = 0
                scale.duration = scale.settlingDuration
                layer.add(scale, forKey: "popIn")
                layer.transform = CATransform3DIdentity
            }
        }
        
        // Trigger SwiftUI entrance state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0)) {
                self.state.appeared = true
            }
        }
        
        // Enable mouse hover selection after entrance animation settles
        // This prevents the cursor's initial position from hijacking selectedIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.state.hoverSelectionEnabled = true
        }
        
        // Monitor actual mouse movement to exit keyboard navigation
        // onHover can't distinguish "mouse moved" vs "rows scrolled past cursor"
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            if self?.state.isKeyboardNavigating == true {
                self?.state.isKeyboardNavigating = false
            }
            return event
        }
    }
    
    /// Paste and keep panel open: copies to clipboard, yields focus to target app (so you can type/paste), simulates Cmd+V
    func dismissAndPaste(_ item: ClipboardHistory.ClipboardEntry) {
        // 1. Copy to clipboard with full fidelity
        NSPasteboard.general.clearContents()
        
        if item.isImage, let data = item.binaryData, let nsImage = NSImage(data: data) {
            NSPasteboard.general.writeObjects([nsImage])
        } else if let fileURLStr = item.fileURL {
            let url: URL
            if fileURLStr.hasPrefix("file://") {
                url = URL(string: fileURLStr) ?? URL(fileURLWithPath: fileURLStr.replacingOccurrences(of: "file://", with: ""))
            } else {
                url = URL(fileURLWithPath: fileURLStr)
            }
            // writeObjects creates sandbox extensions for chat apps (Messages, browsers)
            NSPasteboard.general.writeObjects([url as NSURL])
            // Add legacy type for Finder
            NSPasteboard.general.addTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
            NSPasteboard.general.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        } else {
            NSPasteboard.general.setString(item.content, forType: .string)
        }
        
        // 2. Visual feedback
        state.lastPastedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.state.lastPastedId == item.id {
                self?.state.lastPastedId = nil
            }
        }
        
        // 3. Robust paste: yield focus and wait for target app to actually become completely active
        guard let prevApp = previousApp else { return }
        
        let targetPID = prevApp.processIdentifier
        
        // Prevent NSWorkspace observers from dismissing the panel when we yield focus
        suppressDismiss = true
        
        // Crucial: Pasty MUST explicitly yield key window status so target app's window can take it
        NSApp.deactivate() 
        prevApp.activate(options: .activateIgnoringOtherApps)
        
        class RetryCounter { var count = 0 }
        let counter = RetryCounter()
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let isTargetFront = (currentPID == targetPID)
            let isPastyKey = self?.panel?.isKeyWindow ?? false
            
            // Only paste when Pasty has officially lost key focus and target is front
            if (isTargetFront && !isPastyKey) || counter.count > 10 {
                timer.invalidate()
                // Target app is now frontmost and has key window — safe to send Cmd+V
                Self.simulatePaste()
                
                // After the paste lands, immediately dismiss the window per user request
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.suppressDismiss = false
                    self?.dismiss()
                }
            }
            counter.count += 1
        }
    }
    
    /// Simulate Cmd+V keystroke via CGEvent (requires Accessibility permission only — no Automation needed)
    private static func simulatePaste() {
        // Verify Accessibility permission before attempting to post events
        guard AXIsProcessTrusted() else {
            print("simulatePaste: Accessibility NOT granted — prompting user")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Pasty needs Accessibility access to paste into other apps.\n\nGo to System Settings → Privacy & Security → Accessibility, find Pasty, and toggle it ON.\n\nIf Pasty is already listed, try toggling it OFF then ON again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Use hardcoded key to avoid Swift 6 concurrency error with kAXTrustedCheckOptionPrompt
                    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            return
        }
        
        // Use combinedSessionState — more reliable than hidSystemState for ad-hoc signed apps
        let src = CGEventSource(stateID: .combinedSessionState)
        
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else {
            print("simulatePaste: CGEvent creation failed, falling back to AppleScript")
            simulatePasteViaAppleScript()
            return
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post at session level (not HID level) for broader app compatibility
        keyDown.post(tap: .cgSessionEventTap)
        usleep(20_000) // 20ms delay for target app to be ready
        keyUp.post(tap: .cgSessionEventTap)
    }
    
    /// Fallback: AppleScript-based paste (needs Automation permission but works when CGEvent doesn't)
    private static func simulatePasteViaAppleScript() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error { print("AppleScript paste fallback error: \(error)") }
    }
    
    func dismiss() {
        guard let panel, !suppressDismiss else { return }
        
        // Disconnect live-update callback
        ClipboardHistory.shared.onChange = nil
        
        // Remove global monitor
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        // Remove local mouse monitor
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        
        withAnimation(.easeIn(duration: 0.1)) {
            state.appeared = false
        }
        
        // Scale down + fade out (faster than entrance, no overshoot)
        if let layer = panel.contentView?.layer {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 0.92
            scale.duration = 0.12
            scale.timingFunction = CAMediaTimingFunction(name: .easeIn)
            scale.isRemovedOnCompletion = false
            scale.fillMode = .forwards
            layer.add(scale, forKey: "popOut")
        }
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.hostingController = nil
            
            // Re-activate previous app ONLY after our panel is completely gone
            if let prevApp = self?.previousApp, prevApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                prevApp.activate()
            }
            self?.previousApp = nil
        })
    }
}

// MARK: - NSPanel subclass

class KeyablePanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    private var trackingArea: NSTrackingArea?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true } // Crucial for borderless windows to avoid click beeps
    
    override func keyDown(with event: NSEvent) {
        // If our handler doesn't consume the event, swallow it silently (no Funk beep)
        if keyHandler?(event) != true {
            // Don't call super — super.keyDown plays NSBeep on unhandled keys
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Route Cmd+C/V/X/A through the responder chain
        // Non-activating panels don't participate in NSMenu dispatch,
        // so we must explicitly route these shortcuts
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func sendEvent(_ event: NSEvent) {
        // Intercept arrow keys and Enter/Return at the panel level BEFORE any subview
        // This ensures up/down always navigate the paste list
        if event.type == .keyDown {
            let keyCode = Int(event.keyCode)
            // Arrow up (126), Arrow down (125), Return (36), Delete (51), Escape (53)
            if keyCode == 126 || keyCode == 125 || keyCode == 36 || keyCode == 51 || keyCode == 53 {
                if keyHandler?(event) == true {
                    return // Consumed — don't pass to subviews
                }
            }
        }
        
        if event.type == .leftMouseDown {
            // Let the event through for the SwiftUI Button to pick it up
            super.sendEvent(event)
            return
        }
        super.sendEvent(event)
    }
    
    override func resignKey() {
        super.resignKey()
        // We do NOT dismiss here because we want the panel to stay open
        // even when it explicitly yields focus to the target app to paste!
        // Outside clicks are handled by the globalEventMonitor.
    }
    
    // MARK: - Mouse Tracking for Focus Recovery
    
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        setupTrackingArea()
    }
    
    override func orderOut(_ sender: Any?) {
        removeTrackingArea()
        super.orderOut(sender)
    }
    
    private func setupTrackingArea() {
        guard let contentView else { return }
        removeTrackingArea()
        
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }
    
    private func removeTrackingArea() {
        if let area = trackingArea, let contentView {
            contentView.removeTrackingArea(area)
            trackingArea = nil
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // When mouse enters the panel, reclaim key focus so arrow keys work here
        if !isKeyWindow {
            makeKey()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // When mouse leaves, let the target app have focus back
        // so the user can type in their text field
    }
}
