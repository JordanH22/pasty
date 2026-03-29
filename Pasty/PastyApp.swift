
import SwiftUI
import SwiftData
import AppKit

@main
struct PastyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No visible scenes — everything managed by AppDelegate
        WindowGroup("Hidden", id: "hidden") {
            EmptyView()
        }
        .defaultSize(width: 0, height: 0)
    }
}

// MARK: - App Delegate

/// Custom NSView that handles Cmd+C/V/X/A key equivalents for the popover.
/// NSPopover's internal _NSPopoverWindow doesn't route performKeyEquivalent
/// through the menu system, so we inject this into the popover's view hierarchy.
/// This runs DURING normal event dispatch (unlike a local event monitor which
/// fires BEFORE dispatch), so SwiftUI's .textSelection backing view is engaged.
class KeyEquivalentHostingView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if ["c", "v", "x", "a"].contains(char) {
                let selectors: [String: Selector] = [
                    "c": #selector(NSText.copy(_:)),
                    "v": #selector(NSText.paste(_:)),
                    "x": #selector(NSText.cut(_:)),
                    "a": #selector(NSText.selectAll(_:))
                ]
                if let sel = selectors[char] {
                    if NSApp.sendAction(sel, to: nil, from: self) {
                        return true
                    }
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        // Silently swallow unhandled keys — don't call super (which does NSBeep)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var statusBarMenu: NSMenu!
    var onboardingWindow: NSWindow?
    var popoverKeyMonitor: Any?
    var popoverMouseMonitor: Any?
    let appState = AppState()
    
    let modelContainer: ModelContainer = {
        let schema = Schema([PasteItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    private var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce ODIS-style anti-debugging before spawning threads
        executeODISAntiReversingRoutines()
        
        // Inject an invisible CoreUI Main Menu so Cmd+C/Cmd+V shortcuts work natively in an LSUIElement app
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let icon = NSImage.pastyMenuBarIcon
            icon.isTemplate = true
            icon.accessibilityDescription = "Pasty"
            button.image = icon
            button.action = #selector(statusBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Right-click menu
        statusBarMenu = NSMenu()
        statusBarMenu.addItem(NSMenuItem(title: "Open Pasty", action: #selector(openFromMenu), keyEquivalent: ""))
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(NSMenuItem(title: "Quit Pasty", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: appState.popoverWidth, height: appState.popoverHeight)
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = PopoverView()
            .environment(appState)
            .modelContainer(modelContainer)
        
        let hostingController = NSHostingController(rootView: contentView)
        // Make the hosting view background transparent
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear
        popover.contentViewController = hostingController
        
        // Observe popover show to strip window chrome
        NotificationCenter.default.addObserver(
            forName: NSPopover.willShowNotification,
            object: popover,
            queue: .main
        ) { [weak popover, weak appState] _ in
            appState?.isPopoverVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                guard let popoverWindow = popover?.contentViewController?.view.window else { return }
                popoverWindow.makeKey() // Ensure arrow keys work immediately
                popoverWindow.backgroundColor = .clear
                popoverWindow.isOpaque = false
                popoverWindow.hasShadow = false
                
                // Inject key equivalent handler into the popover window's frame view
                // (NOT the contentView which is NSHostingController.view — that's unsupported)
                // This handles Cmd+C/V/X/A during normal event dispatch
                if let frameView = popoverWindow.contentView?.superview {
                    let hasHandler = frameView.subviews.contains(where: { $0 is KeyEquivalentHostingView })
                    if !hasHandler {
                        let handler = KeyEquivalentHostingView()
                        handler.frame = .zero
                        frameView.addSubview(handler)
                    }
                }
                
                // Only strip the frame view's DIRECT children — NOT the content view hierarchy
                // This removes the popover's built-in chrome without breaking SwiftUI interactivity
                if let frameView = popoverWindow.contentView?.superview {
                    frameView.wantsLayer = true
                    frameView.layer?.borderWidth = 0
                    frameView.layer?.borderColor = .clear
                    
                    for subview in frameView.subviews {
                        // Hide visual effect views at the frame level only
                        if subview is NSVisualEffectView {
                            subview.isHidden = true
                        }
                        // Also check for border/background views by class name
                        let className = String(describing: type(of: subview))
                        if className.contains("Border") || className.contains("Background") {
                            subview.isHidden = true
                        }
                    }
                }
            }
        }
        
        // Clean up key/mouse monitors when popover closes
        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self, weak appState] _ in
            appState?.isPopoverVisible = false
            if let monitor = self?.popoverKeyMonitor {
                NSEvent.removeMonitor(monitor)
                self?.popoverKeyMonitor = nil
            }
            if let monitor = self?.popoverMouseMonitor {
                NSEvent.removeMonitor(monitor)
                self?.popoverMouseMonitor = nil
            }
        }
        
        // Register global hotkey — opens floating clipboard panel at cursor
        HotkeyManager.shared.onToggle = {
            DispatchQueue.main.async {
                // Enforce Activation Wall on Global Hotkey
                if !LicenseManager.shared.isActivated {
                    self.onboardingWindow?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
                ClipboardPanelController.shared.toggle()
            }
        }
        HotkeyManager.shared.register()
        
        // Start clipboard history monitoring — wire SwiftData context
        ClipboardHistory.shared.modelContext = modelContainer.mainContext
        ClipboardHistory.shared.maxItems = appState.historyLimit
        ClipboardHistory.shared.startMonitoring()
        ScreenshotMonitor.shared.startMonitoring()
        
        // Update network status
        appState.isOnline = PasteService.shared.isOnline
        
        // Hide any stray windows
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window != self.onboardingWindow {
                    window.orderOut(nil)
                }
            }
        }
        
        // Enforce Lemon Squeezy Software Activation Wall
        if !LicenseManager.shared.isActivated {
            showActivationWindow()
        } else if !hasCompletedOnboarding {
            // Only show onboarding if they actually own the software
            showOnboarding()
        }
    }
    
    // MARK: - Status Bar Actions
    
    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        // Enforce Activation Wall
        if !LicenseManager.shared.isActivated {
            self.onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right-click: show quit menu
            popover.performClose(nil)
            statusItem.menu = statusBarMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil  // Reset so left-click works again
        } else {
            // Left-click: toggle popover
            togglePopover(sender)
        }
    }
    
    @objc func openFromMenu() {
        guard let button = statusItem.button else { return }
        togglePopover(button)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.contentSize = NSSize(width: appState.popoverWidth, height: appState.popoverHeight)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            
            // Reset popover keyboard state
            appState.popoverSelectedIndex = 0
            appState.popoverKeyboardNavigating = false
            appState.popoverHoverEnabled = false
            
            // Enable hover after entrance settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.appState.popoverHoverEnabled = true
            }
            
            // Clean up any stale monitors from a previous show
            if let m = popoverKeyMonitor { NSEvent.removeMonitor(m); popoverKeyMonitor = nil }
            if let m = popoverMouseMonitor { NSEvent.removeMonitor(m); popoverMouseMonitor = nil }
            
            // Local key monitor for Cmd+C and arrow keys
            popoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                
                // DON'T intercept Cmd+C/V/X/A here — the local monitor fires
                // BEFORE the window's event dispatch, so SwiftUI's text selection
                // view isn't engaged yet. KeyEquivalentHostingView handles this.
                
                // Arrow keys: navigate the list
                let keyCode = Int(event.keyCode)
                if keyCode == 125 { // Down arrow
                    self.appState.popoverKeyboardNavigating = true
                    let maxIndex = self.appState.popoverItemCount - 1
                    if self.appState.popoverSelectedIndex < maxIndex {
                        self.appState.popoverSelectedIndex += 1
                    }
                    return nil
                }
                if keyCode == 126 { // Up arrow
                    self.appState.popoverKeyboardNavigating = true
                    if self.appState.popoverSelectedIndex > 0 {
                        self.appState.popoverSelectedIndex -= 1
                    }
                    return nil
                }
                
                return event
            }
            
            // Mouse movement monitor to exit keyboard navigation
            popoverMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                if self?.appState.popoverKeyboardNavigating == true {
                    self?.appState.popoverKeyboardNavigating = false
                }
                return event
            }
            
            if appState.autoCapture {
                appState.currentClipboardContent = ClipboardService.shared.currentString() ?? ""
            }
        }
    }
    
    // MARK: - Onboarding Window
    
    private func showOnboarding() {
        let onboardingView = OnboardingView {
            self.completeOnboarding()
        }
        
        let hostingController = NSHostingController(rootView: onboardingView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Pasty"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 520, height: 640))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        self.onboardingWindow = window
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingWindow?.close()
        onboardingWindow = nil
    }
    
    // MARK: - Dedicated NSWindow Subclass for Key Logging
    class KeyWindow: NSWindow {
        override var canBecomeKey: Bool { return true }
        override var canBecomeMain: Bool { return true }
        
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
                case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
                case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
                case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
                default: break
                }
            }
            return super.performKeyEquivalent(with: event)
        }
    }
    
    private func showActivationWindow() {
        let actView = ActivationView()
        let hostingController = NSHostingController(rootView: actView)
        
        let window = KeyWindow(contentViewController: hostingController)
        window.title = "Activate Pasty"
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 480, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        
        // Escalate macOS application policy to intercept raw keystrokes flawlessly
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Bind to existing window reference to leverage existing closure logic
        self.onboardingWindow = window 
    }
    
    // MARK: - Military-Grade Anti-Debugging (ODIS Style)
    
    @inline(__always)
    private func executeODISAntiReversingRoutines() {
        // 1. PT_DENY_ATTACH (31) 
        // Strips all debugger read/write access. If LLDB/Ghidra injects, the kernel instantly terminates the process.
        let handle = dlopen(nil, RTLD_GLOBAL | RTLD_NOW)
        let ptrace_ptr = dlsym(handle, "ptrace")
        if let ptrace_ptr = ptrace_ptr {
            typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
            let ptrace = unsafeBitCast(ptrace_ptr, to: PtraceType.self)
            _ = ptrace(31, 0, 0, 0)
        }
        dlclose(handle)
        
        // 2. Sysctl Tracer Check
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let sysctlResult = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        if sysctlResult == 0 {
            // P_TRACED flag is 0x800. If an active tracer is detected by the kernel, immediately brick execution.
            if (info.kp_proc.p_flag & 0x800) != 0 {
                exit(17) // Hex code for unauthorized runtime hooking
            }
        }
    }
    

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardHistory.shared.stopMonitoring()
        ScreenshotMonitor.shared.stopMonitoring()
        HotkeyManager.shared.unregister()
    }
    
    // MARK: - Window Delegate
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == onboardingWindow {
            if !LicenseManager.shared.isActivated {
                // Closed without activating — terminate
                NSApp.terminate(nil)
            } else {
                // Activated — return to stealth mode
                NSApp.setActivationPolicy(.accessory)
                // Show onboarding for brand-new users who haven't seen it yet
                if !hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showOnboarding()
                    }
                }
            }
        }
    }
}

// MARK: - Menu Bar Icon

extension NSImage {
    static var pastyMenuBarIcon: NSImage {
        let size = NSSize(width: 18, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        // Main pasty body (semi-circle)
        ctx.move(to: CGPoint(x: 2, y: 3))
        ctx.addCurve(to: CGPoint(x: 16, y: 3), control1: CGPoint(x: 2, y: 12), control2: CGPoint(x: 16, y: 12))
        ctx.closePath()
        ctx.strokePath()
        
        // Crimped edge (little loops/bumps along the top)
        ctx.setLineWidth(1.0)
        let points: [(CGFloat, CGFloat)] = [
            (3.0, 7.5), (5.5, 10.5), (9.0, 11.5), (12.5, 10.5), (15.0, 7.5)
        ]
        
        for p in points {
            ctx.move(to: CGPoint(x: p.0, y: p.1))
            ctx.addLine(to: CGPoint(x: p.0 + 1.5, y: p.1 + 1.5))
        }
        ctx.strokePath()
        
        image.unlockFocus()
        return image
    }
}
