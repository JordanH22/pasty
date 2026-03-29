import Foundation
import Cocoa
import ApplicationServices

class GlideEngine {
    static let shared = GlideEngine()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // --- Glide State ---
    private var isGliding: Bool = false
    private var originMouseLocation: CGPoint = .zero
    private var currentGlideLocation: CGPoint = .zero
    private var glideEndTimer: Timer?
    
    // --- OG Mode State ---
    private var deltaX: Double = 0.0
    private var deltaY: Double = 0.0
    
    // ═══════════════════════════════════════════════════════════════
    // Double-Tap Selection Glide
    //
    // Double-tap starts a "selection glide": we simulate holding
    // the mouse button down at the tap point, then scroll/finger
    // movements extend the selection by posting synthetic drag
    // events. When fingers lift (scroll ends), we release.
    //
    // It's the glide engine but with click-drag for selection.
    // ═══════════════════════════════════════════════════════════════
    
    private let syntheticEventTag: Int64 = 0xBEEF
    private var isSelectionGliding: Bool = false
    private var selectionAnchor: CGPoint = .zero
    // Manual double-tap tracking
    private var lastTapTime: CFAbsoluteTime = 0
    private var lastTapLocation: CGPoint = .zero
    private let doubleTapTimeWindow: Double = 2.0   // 2s — user's taps are 0.7-1.1s apart
    private let doubleTapDistanceTolerance: Double = 100.0  // very loose to allow 2-finger centroid shifts
        private var selectionEndTimer: Timer?
    
    // ═══════════════════════════════════════════════════════════════
    // Velocity Classifier — iOS-style intent detection
    // ═══════════════════════════════════════════════════════════════
    
    private enum GestureIntent {

        case undecided
        case scroll

        case glide
    }
    
    private var gestureIntent: GestureIntent = .undecided
    private var gestureStartTime: CFAbsoluteTime = 0
    private var gestureSamples: [(magnitude: Double, time: CFAbsoluteTime)] = []
    private let decisionSamples: Int = 4
    private let velocityThreshold: Double = 6.0
    private let burstVelocityThreshold: Double = 80.0
    
    // --- Shake Detection ---
    
    private var prefs: PreferencesManager { PreferencesManager.shared }
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start() {
        guard AXIsProcessTrusted() else {
            print("❌ Accessibility Permission Missing.")
            return
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: cgEventCallback,
            userInfo: nil
        )
        
        guard let tap = eventTap else {
            print("❌ Failed to create event tap.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("🚀 GlideEngine active.")
    }
    
    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        endGlide(commit: false)
        endSelectionGlide()
        print("🛑 GlideEngine stopped.")
    }
    
    // MARK: - Event Router
    
    func processEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard prefs.engineEnabled else {
            return Unmanaged.passUnretained(event)
        }
        
        switch type {
        case .leftMouseDown, .rightMouseDown:
            return handleMouseDown(event: event)
        case .leftMouseUp, .rightMouseUp:
            return handleMouseUp(event: event)
        case .leftMouseDragged, .rightMouseDragged:
            return handleMouseDragged(event: event)
        case .mouseMoved:
            return handleMouseMoved(event: event)
        case .scrollWheel:
            return processScroll(event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
    
    // MARK: - Double-Tap Detection
    
    private func handleMouseDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Skip our own synthetic events (prevents loop!)
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }
        
        let clickCount = event.getIntegerValueField(.mouseEventClickState)
        let location = event.location
        let now = CFAbsoluteTimeGetCurrent()
        
        let dtElapsed = now - lastTapTime
        let dtDistance = lastTapTime > 0 ? hypot(location.x - lastTapLocation.x, location.y - lastTapLocation.y) : -1
        print("🖱️ TAP cs=\(clickCount) (\(Int(location.x)),\(Int(location.y))) dt=\(String(format: "%.2f", dtElapsed))s d=\(Int(dtDistance))px selGlide=\(isSelectionGliding)")
        
        // If we're in selection glide, a REAL click ends it
        if isSelectionGliding {
            endSelectionGlide()
            lastTapTime = now     // Reset the timer so it doesn't trigger double-tap again!
            lastTapLocation = location
            return nil // Consume Tap 3 Down! We are just dropping the selection.
        }
        
        // Detect double-tap
        let isOurDoubleTap = lastTapTime > 0 && dtElapsed < doubleTapTimeWindow && dtDistance < doubleTapDistanceTolerance && dtDistance >= 0
        let isMacOSDoubleTap = clickCount >= 2
        
        if prefs.doubleTapSelectEnabled && (isOurDoubleTap || isMacOSDoubleTap) {
            beginSelectionGlide(at: location)
            lastTapTime = 0
            lastTapLocation = .zero
            // SWALLOW Tap 2 Down! We completely shield the app from the 2nd click.
            // We will inject a synthetic click ONLY when they actually start moving!
            return nil
        }
        
        lastTapTime = now
        lastTapLocation = location
        return Unmanaged.passUnretained(event)
    }
    
    private var needsSyntheticMouseDown = false
    
    private func handleMouseDragged(event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }
        
        if isSelectionGliding {
            if needsSyntheticMouseDown {
                injectDelayedDragAnchor(at: event.location, clickState: 1)
            }
            
            // It's natively a drag. Ensure clickState is 1 just in case, and pass it.
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            selectionEndTimer?.invalidate()
            selectionEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.endSelectionGlide()
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleMouseUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Skip our own synthetic mouseUp events
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }
        
        if isSelectionGliding {
            // Consume the physical Tap 2 Up!
            // We swallowed Tap 2 Down, and now Tap 2 Up. The app is entirely ignorant of the double-tap.
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // Convert 1-finger movement into drag-selection!
    private func handleMouseMoved(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isSelectionGliding else {
            return Unmanaged.passUnretained(event)
        }
        
        let location = event.location
        
        if needsSyntheticMouseDown {
            injectDelayedDragAnchor(at: location, clickState: 1)
        }
        
        // Inline mutation! Converting mouseMoved to leftMouseDragged natively!
        event.type = .leftMouseDragged
        event.setIntegerValueField(.mouseEventClickState, value: 1) // explicitly set single click drag
        
        // Reset end timer (0.3s snap timeout mimics native finger release)
        selectionEndTimer?.invalidate()
        selectionEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.endSelectionGlide()
        }
        
        // Pass the modified event through so WindowServer handles the cursor naturally
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Selection Glide (Double-Tap + Scroll = Free Highlight)
    
    private func beginSelectionGlide(at location: CGPoint) {
        isSelectionGliding = true
        needsSyntheticMouseDown = true  // We wait for the user to move before dropping the anchor!
        selectionAnchor = location
        currentGlideLocation = location
        
        // Safety timer: If they double tap but NEVER move their mouse, drop the virtual hold.
        selectionEndTimer?.invalidate()
        selectionEndTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.endSelectionGlide()
        }
        
        print("🔵 Selection glide WAITING FOR MOTION at (\(Int(location.x)),\(Int(location.y)))")
    }
    
    private func injectDelayedDragAnchor(at location: CGPoint, clickState: Int64) {
        needsSyntheticMouseDown = false
        currentGlideLocation = location
        let src = CGEventSource(stateID: .hidSystemState)
        if let mouseDown = CGEvent(mouseEventSource: src,
                                   mouseType: .leftMouseDown,
                                   mouseCursorPosition: location,
                                   mouseButton: .left) {
            mouseDown.setIntegerValueField(.mouseEventClickState, value: clickState) // single click for drag
            mouseDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            mouseDown.post(tap: .cghidEventTap)
        }
        print("⚓️ Selection glide DRAG ANCHOR DROPPED at (\(Int(location.x)),\(Int(location.y)))")
    }
    
    private func processSelectionScroll(event: CGEvent) -> Unmanaged<CGEvent>? {
        let dx = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let dy = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        
        if needsSyntheticMouseDown {
            injectDelayedDragAnchor(at: currentGlideLocation, clickState: 1)
        }
        
        // Move cursor position (amplified)
        currentGlideLocation.x += CGFloat(dx * prefs.glideSpeed)
        currentGlideLocation.y += CGFloat(dy * prefs.glideSpeed)
        
        // Clamp to screen
        if let screen = NSScreen.main {
            let bounds = screen.frame
            currentGlideLocation.x = max(bounds.minX, min(currentGlideLocation.x, bounds.maxX))
            currentGlideLocation.y = max(bounds.minY, min(currentGlideLocation.y, bounds.maxY))
        }
        
        // Warp cursor to new position
        CGWarpMouseCursorPosition(currentGlideLocation)
        
        // Post synthetic drag event (extends the selection)
        let src = CGEventSource(stateID: .hidSystemState)
        if let drag = CGEvent(mouseEventSource: src,
                              mouseType: .leftMouseDragged,
                              mouseCursorPosition: currentGlideLocation,
                              mouseButton: .left) {
            drag.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            drag.post(tap: .cghidEventTap)
        }
        
        // Reset end timer
        selectionEndTimer?.invalidate()
        selectionEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.endSelectionGlide()
        }
        
        return nil  // consume scroll
    }
    
    private func endSelectionGlide() {
        guard isSelectionGliding else { return }
        isSelectionGliding = false
        selectionEndTimer?.invalidate()
        selectionEndTimer = nil
        
        // If they double tapped but never moved, we never injected a mouseDown. No need to mouseUp!
        if needsSyntheticMouseDown {
            needsSyntheticMouseDown = false
            print("🔴 Selection glide CANCELLED (no motion detected)")
            return
        }
        
        // Read current correct cursor location before posting
        var currentLocation = currentGlideLocation
        if let event = CGEvent(source: nil) {
            currentLocation = event.location
        }
        
        // Release the virtual mouse button (ends text selection)
        let src = CGEventSource(stateID: .hidSystemState)
        if let mouseUp = CGEvent(mouseEventSource: src,
                                 mouseType: .leftMouseUp,
                                 mouseCursorPosition: currentLocation,
                                 mouseButton: .left) {
            mouseUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            mouseUp.post(tap: .cghidEventTap)
        }
        
        print("🔴 Selection glide ENDED at (\(Int(currentLocation.x)),\(Int(currentLocation.y)))")
    }
    
    // MARK: - Scroll Router (Velocity Classifier)
    
    private var accumulatedDx: Double = 0
    private var accumulatedDy: Double = 0
    
    private func processScroll(event: CGEvent) -> Unmanaged<CGEvent>? {
        // If in selection glide mode, ALL scrolls extend the selection
        if isSelectionGliding {
            return processSelectionScroll(event: event)
        }
        
        let mouseLocation = event.location
        
        if gestureIntent == .scroll {
            let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            if phase == 4 || phase == 0 && momentum == 0 {
                resetGestureClassifier()
            }
            return Unmanaged.passUnretained(event)
        }
        
        if gestureIntent == .glide || isGliding {
            return processGlide(event: event, mouseLocation: mouseLocation)
        }
        
        let dx = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let dy = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let magnitude = sqrt(dx * dx + dy * dy)
        let now = CFAbsoluteTimeGetCurrent()
        
        accumulatedDx += dx
        accumulatedDy += dy
        
        if gestureSamples.isEmpty {
            let systemWide = AXUIElementCreateSystemWide()
            var element: AXUIElement?
            let err = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(mouseLocation.y), &element)
            
            if !(err == .success && isTextElement(element!)) {
                gestureIntent = .scroll
                return Unmanaged.passUnretained(event)
            }
            gestureStartTime = CFAbsoluteTimeGetCurrent()
        }
        
        gestureSamples.append((magnitude: magnitude, time: now))
        
        if gestureSamples.count >= decisionSamples {
            // iOS-STYLE DIRECTIONAL LOCK
            // Evaluate the accumulated vectors over the decision window.
            if abs(accumulatedDy) > abs(accumulatedDx) {
                // Primary intent is VERTICAL. Lock into native scrolling!
                gestureIntent = .scroll
                gestureSamples.removeAll()
                return Unmanaged.passUnretained(event)
            } else {
                // Primary intent is HORIZONTAL. Lock into SwipeSelect Gliding!
                gestureIntent = .glide
                gestureSamples.removeAll()
                return processGlide(event: event, mouseLocation: mouseLocation)
            }
        }
        
        return nil
    }
    
    private func processGlide(event: CGEvent, mouseLocation: CGPoint) -> Unmanaged<CGEvent>? {
        if prefs.cursorMode == "freeGlide" {
            return processFreeGlide(event: event, mouseLocation: mouseLocation)
        } else {
            return processOGMode(event: event)
        }
    }
    
    private func resetGestureClassifier() {
        gestureIntent = .undecided
        gestureSamples.removeAll()
        gestureStartTime = 0
        accumulatedDx = 0
        accumulatedDy = 0
    }
    
    // MARK: - Free Glide Mode
    // ... skipping Free Glide for now ...
    private func processFreeGlide(event: CGEvent, mouseLocation: CGPoint) -> Unmanaged<CGEvent>? {
        if !isGliding {
            beginGlide(at: mouseLocation)
        }
        
        let dx = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let dy = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        
        // --- DYNAMIC ACCELERATION CURVE ---
        // Upgraded to a strict 2.0 Quadratic curve pivoted at 10px!
        // Slow precision landing (<5px): Speed drops to 20-30% for surgical character targeting.
        // Fast swiping flings (>20px): Multiplies speed exponentially to traverse the whole screen.
        let magnitude = sqrt(dx * dx + dy * dy)
        let normalizedMag = magnitude / 10.0
        
        let rawDampener = magnitude > 0 ? (pow(normalizedMag, 2.0) * 10.0) / magnitude : 0.0
        // Cap the dampener floor at 0.15 so micro-movements don't feel completely "stuck"
        let accelerationDampener = max(0.15, rawDampener)
        
        let dynamicMultiplier = prefs.glideSpeed * accelerationDampener
        
        currentGlideLocation.x += CGFloat(dx * dynamicMultiplier)
        currentGlideLocation.y += CGFloat(dy * dynamicMultiplier)
        
        if let screen = NSScreen.main {
            let bounds = screen.frame
            currentGlideLocation.x = max(bounds.minX, min(currentGlideLocation.x, bounds.maxX))
            currentGlideLocation.y = max(bounds.minY, min(currentGlideLocation.y, bounds.maxY))
        }
        
        CGWarpMouseCursorPosition(currentGlideLocation)
        
        DispatchQueue.main.async { [loc = self.currentGlideLocation] in
            CursorOverlay.shared.move(to: loc)
        }
        
        scheduleGlideEnd()
        return nil
    }
    
    // MARK: - OG SwipeSelection Mode
    
    private func processOGMode(event: CGEvent) -> Unmanaged<CGEvent>? {
        if !isGliding {
            isGliding = true
            deltaX = 0
            deltaY = 0
            originMouseLocation = event.location
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
        }
        
        let dx = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        
        // Direction is strictly locked. Discard vertical (dy) for cursor completely.
        // Invert dx so swipe left maps to left arrow, swipe right maps to right arrow.
        deltaX += -dx
        
        let threshold = prefs.ogSensitivity
        
        while abs(deltaX) >= threshold {
            if deltaX > 0 {
                fireKeystroke(keyCode: 123) // Left Arrow
                deltaX -= threshold
            } else {
                fireKeystroke(keyCode: 124) // Right Arrow
                deltaX += threshold
            }
        }
        
        scheduleGlideEnd()
        return nil
    }
    
    // MARK: - Glide State Machine
    
    private func beginGlide(at location: CGPoint) {
        isGliding = true
        originMouseLocation = location
        currentGlideLocation = location
        CGAssociateMouseAndMouseCursorPosition(0)
        
        DispatchQueue.main.async {
            CursorOverlay.shared.show(at: location)
        }
    }
    
    private func endGlide(commit: Bool = true) {
        guard isGliding else { return }
        isGliding = false
        glideEndTimer?.invalidate()
        glideEndTimer = nil
        resetGestureClassifier()
        
        CGAssociateMouseAndMouseCursorPosition(1)
        
        if commit && prefs.cursorMode == "freeGlide" {
            let landingPoint = currentGlideLocation
            let systemWide = AXUIElementCreateSystemWide()
            var element: AXUIElement?
            let err = AXUIElementCopyElementAtPosition(systemWide, Float(landingPoint.x), Float(landingPoint.y), &element)
            
            if err == .success, let el = element, isTextElement(el) {
                DispatchQueue.main.async {
                    CursorOverlay.shared.popAndHide(at: landingPoint)
                }
                simulateClick(at: landingPoint)
            } else {
                DispatchQueue.main.async { CursorOverlay.shared.hide() }
                CGWarpMouseCursorPosition(originMouseLocation)
            }
        } else if commit && prefs.cursorMode == "ogSwipeSelection" {
            DispatchQueue.main.async { CursorOverlay.shared.hide() }
            NSCursor.unhide()
            CGWarpMouseCursorPosition(originMouseLocation)
            deltaX = 0
            deltaY = 0
        } else {
            DispatchQueue.main.async { CursorOverlay.shared.hide() }
        }
    }
    
    private func scheduleGlideEnd() {
        glideEndTimer?.invalidate()
        glideEndTimer = Timer.scheduledTimer(withTimeInterval: prefs.glideEndDelay, repeats: false) { [weak self] _ in
            self?.endGlide(commit: true)
        }
    }
    
    // MARK: - Text Field Detection
    
    private func isTextElement(_ element: AXUIElement) -> Bool {
        var roleRaw: CFTypeRef?
        let roleErr = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRaw)
        guard roleErr == .success, let role = roleRaw as? String else { return false }
        
        if role == "AXTextField" || role == "AXTextArea" || role == "AXComboBox" {
            return true
        }
        
        var subroleRaw: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRaw)
        if subroleRaw as? String == "AXTextEntry" { return true }
        
        var editableRaw: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editableRaw) == .success,
           let editable = editableRaw as? Bool, editable {
            return true
        }
        
        return false
    }
    
    // MARK: - Event Synthesis
    
    private func simulateClick(at position: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let mouseDown = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: position, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: position, mouseButton: .left) else { return }
        mouseDown.post(tap: .cghidEventTap)
        usleep(10_000)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    private func fireKeystroke(keyCode: CGKeyCode, shift: Bool = false, option: Bool = false, command: Bool = false) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else { return }
        
        var flags: CGEventFlags = []
        if shift { flags.insert(.maskShift) }
        if option { flags.insert(.maskAlternate) }
        if command { flags.insert(.maskCommand) }
        
        if !flags.isEmpty {
            keyDown.flags = flags
            keyUp.flags = flags
        }
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

// MARK: - Global C-Callback

func cgEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    return GlideEngine.shared.processEvent(type: type, event: event)
}
