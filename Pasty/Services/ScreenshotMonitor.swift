import Cocoa
import OSLog
import CoreGraphics

/// Three-pronged screenshot/recording monitor:
/// 1. CGEvent tap — intercepts ⌘⇧3/4 with Ctrl for instant clipboard capture + saves to Desktop.
/// 2. Process monitoring — detects ⌘⇧5 panel close for instant recording placeholder.
/// 3. DispatchSource watcher — detects new files on Desktop for near-instant pickup.
@MainActor
final class ScreenshotMonitor {
    static let shared = ScreenshotMonitor()
    private let logger = Logger(subsystem: "com.pasty.app", category: "screenshot-monitor")
    
    /// CGEvent tap for intercepting screenshot shortcuts
    nonisolated(unsafe) static var eventTapRef: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    
    /// Desktop directory watcher
    private var desktopWatcher: DispatchSourceFileSystemObject?
    private var desktopFileDescriptor: Int32 = -1
    private var knownCaptureFiles = Set<String>()
    private var pollTimer: Timer?
    
    /// Recording placeholder tracking
    private var pendingPlaceholderID: UUID?
    private var placeholderCleanupTask: DispatchWorkItem?
    
    func startMonitoring() {
        if ScreenshotMonitor.eventTapRef == nil {
            if !installScreenshotEventTap() {
                retryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        if self?.installScreenshotEventTap() == true {
                            self?.retryTimer?.invalidate()
                            self?.retryTimer = nil
                        }
                    }
                }
            }
        }
        
        startProcessMonitoring()
        startDesktopWatcher()
        cleanupStuckPlaceholders()
        
        logger.info("Screenshot monitor started.")
    }
    
    func stopMonitoring() {
        retryTimer?.invalidate()
        retryTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        placeholderCleanupTask?.cancel()
        stopDesktopWatcher()
        removeScreenshotEventTap()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        logger.info("Screenshot monitor stopped.")
    }
    
    // MARK: - CGEvent Tap (⌘⇧3/4 → Clipboard + Desktop File)
    
    @discardableResult
    private func installScreenshotEventTap() -> Bool {
        guard AXIsProcessTrusted() else {
            logger.info("Accessibility not yet granted — instant screenshot capture inactive.")
            return false
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: screenshotEventCallback,
            userInfo: nil
        ) else {
            logger.warning("Failed to create CGEvent tap.")
            return false
        }
        
        ScreenshotMonitor.eventTapRef = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Screenshot event tap installed — ⌘⇧3/4 → clipboard + Desktop file.")
        return true
    }
    
    private func removeScreenshotEventTap() {
        if let tap = ScreenshotMonitor.eventTapRef {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        ScreenshotMonitor.eventTapRef = nil
        runLoopSource = nil
    }
    
    /// Save clipboard screenshot to Desktop as a file
    func saveClipboardScreenshotToDesktop() {
        let pb = NSPasteboard.general
        
        guard let tiffData = pb.data(forType: .tiff),
              let image = NSImage(data: tiffData) else { return }
        
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot \(timestamp).png"
        
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            knownCaptureFiles.insert(filename)
            logger.info("Saved screenshot to Desktop: \(filename)")
        } catch {
            logger.error("Failed to save screenshot to Desktop: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Process Monitoring (⌘⇧5 Panel — Recording Detection)
    // Note: ⌘⇧3/4 use our Ctrl injection so screencaptureui does NOT launch for those.
    // screencaptureui ONLY launches for ⌘⇧5 panel (recordings + panel screenshots).
    
    private func startProcessMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        logger.info("Process monitoring started for screencaptureui (⌘⇧5 only).")
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.screencaptureui" else { return }
        
        Task { @MainActor in
            self.logger.info("screencaptureui terminated (⌘⇧5 panel closed)")
            self.handlePanelClosed()
        }
    }
    
    private func handlePanelClosed() {
        guard pendingPlaceholderID == nil else { return }
        
        // Add placeholder immediately — we'll resolve it one of 3 ways:
        // 1. Recording file appears → update placeholder with thumbnail
        // 2. Screenshot file appears → remove placeholder (screenshot handled separately)
        // 3. Nothing appears (user cancelled) → remove placeholder after timeout
        let placeholderID = UUID()
        pendingPlaceholderID = placeholderID
        ClipboardHistory.shared.addPlaceholderRecording(id: placeholderID)
        logger.info("Added recording placeholder — waiting for file...")
        
        // Auto-cleanup if nothing resolves within 15 seconds (user cancelled or screenshot)
        placeholderCleanupTask?.cancel()
        let cleanup = DispatchWorkItem { [weak self] in
            guard let self, self.pendingPlaceholderID == placeholderID else { return }
            self.pendingPlaceholderID = nil
            ClipboardHistory.shared.removeStuckPlaceholders()
            self.logger.info("Removed unresolved placeholder (timeout)")
        }
        placeholderCleanupTask = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: cleanup)
    }
    
    // MARK: - Desktop Directory Watcher (DispatchSource)
    
    private var desktopURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }
    
    private func startDesktopWatcher() {
        snapshotExistingFiles()
        
        let path = desktopURL.path
        desktopFileDescriptor = open(path, O_EVTONLY)
        
        guard desktopFileDescriptor >= 0 else {
            logger.warning("Cannot open Desktop for watching — falling back to polling only.")
            startPolling(interval: 2.0)
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: desktopFileDescriptor,
            eventMask: .write,
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                // Stagger checks to catch files at different write stages
                self?.checkForNewFiles()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self?.checkForNewFiles() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self?.checkForNewFiles() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { self?.checkForNewFiles() }
            }
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.desktopFileDescriptor, fd >= 0 {
                close(fd)
                self?.desktopFileDescriptor = -1
            }
        }
        
        source.resume()
        desktopWatcher = source
        
        // Fallback polling (safety net — DispatchSource handles realtime)
        startPolling(interval: 10.0)
        
        logger.info("Desktop watcher started (DispatchSource + fallback poll).")
    }
    
    private func stopDesktopWatcher() {
        desktopWatcher?.cancel()
        desktopWatcher = nil
    }
    
    private func startPolling(interval: TimeInterval) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewFiles()
            }
        }
    }
    
    private func snapshotExistingFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }
        
        for file in files where Self.isCaptureFile(file.lastPathComponent) {
            knownCaptureFiles.insert(file.lastPathComponent)
        }
        
        logger.info("Desktop snapshot — \(self.knownCaptureFiles.count) existing capture files")
    }
    
    private func checkForNewFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for file in files {
            let name = file.lastPathComponent
            guard Self.isCaptureFile(name), !knownCaptureFiles.contains(name) else { continue }
            
            guard let values = try? file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                  let created = values.creationDate,
                  Date().timeIntervalSince(created) < 30 else {
                knownCaptureFiles.insert(name)
                continue
            }
            
            let fileSize = values.fileSize ?? 0
            guard fileSize > 500 else { continue }
            
            knownCaptureFiles.insert(name)
            let isRecording = Self.isRecordingFile(name)
            logger.info("New capture: \(name) (\(fileSize) bytes, recording=\(isRecording))")
            
            if isRecording, let placeholderID = pendingPlaceholderID {
                // Recording file found — update the placeholder with real data
                pendingPlaceholderID = nil
                placeholderCleanupTask?.cancel()
                ClipboardHistory.shared.updatePlaceholderRecording(id: placeholderID, url: file)
                logger.info("Updated recording placeholder with real file")
            } else if Self.isScreenshotFile(name), pendingPlaceholderID != nil {
                // Screenshot from ⌘⇧5 panel — remove the recording placeholder
                pendingPlaceholderID = nil
                placeholderCleanupTask?.cancel()
                ClipboardHistory.shared.removeStuckPlaceholders()
                // Process the screenshot normally
                ClipboardHistory.shared.processExternalScreenshot(url: file)
                logger.info("Screenshot from ⌘⇧5 — removed recording placeholder, added screenshot")
            } else {
                // No placeholder context — process normally
                ClipboardHistory.shared.processExternalScreenshot(url: file)
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupStuckPlaceholders() {
        ClipboardHistory.shared.removeStuckPlaceholders()
    }
    
    // MARK: - Helpers
    
    nonisolated static func isCaptureFile(_ filename: String) -> Bool {
        return isScreenshotFile(filename) || isRecordingFile(filename)
    }
    
    nonisolated static func isScreenshotFile(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        let imageExts = [".png", ".jpg", ".jpeg", ".heic", ".tiff", ".bmp", ".gif", ".webp"]
        return (lower.hasPrefix("screenshot") || lower.hasPrefix("cleanshot"))
            && imageExts.contains(where: { lower.hasSuffix($0) })
    }
    
    nonisolated static func isRecordingFile(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasPrefix("screen recording") && (lower.hasSuffix(".mov") || lower.hasSuffix(".mp4"))
    }
}

// MARK: - CGEvent Callback

private func screenshotEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = ScreenshotMonitor.eventTapRef {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }
    
    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }
    
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    
    // ⌘⇧3 (full screen) or ⌘⇧4 (selection) — NOT ⌘⇧5
    let isScreenshotShortcut = (keyCode == 20 || keyCode == 21)
    let hasCmdShift = flags.contains(.maskCommand) && flags.contains(.maskShift)
    let hasCtrl = flags.contains(.maskControl)
    
    if isScreenshotShortcut && hasCmdShift && !hasCtrl {
        event.flags = flags.union(.maskControl)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                ScreenshotMonitor.shared.saveClipboardScreenshotToDesktop()
            }
        }
    }
    
    return Unmanaged.passRetained(event)
}
