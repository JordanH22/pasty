import Foundation
import AppKit
import AVFoundation
import SwiftData
import os.log

extension NSImage {
    /// Resize image to fit within maxWidth using CGContext (faster than lockFocus)
    func resizedToFit(maxWidth: CGFloat) -> NSImage {
        guard self.size.width > maxWidth else { return self }
        let scale = maxWidth / self.size.width
        let newWidth = Int(maxWidth)
        let newHeight = Int(self.size.height * scale)
        
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return self }
        
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        guard let resized = ctx.makeImage() else { return self }
        return NSImage(cgImage: resized, size: NSSize(width: newWidth, height: newHeight))
    }
}

@MainActor
final class ClipboardHistory: @unchecked Sendable {
    static let shared = ClipboardHistory()
    
    private let logger = Logger(subsystem: "com.pasty.app", category: "clipboard-history")
    private var timer: Timer?
    private nonisolated(unsafe) var lastChangeCount: Int
    /// Tracks changeCount when Pasty itself pastes, so the monitor skips re-capturing it
    private var selfPasteChangeCount: Int = -1
    
    private(set) var items: [ClipboardEntry] = []
    var maxItems: Int = 50
    var onChange: (() -> Void)?
    
    /// Call this when Pasty writes to the pasteboard itself (e.g. dismissAndPaste).
    /// The monitor will skip the next clipboard change to avoid re-capturing our own paste.
    func suppressNextChange() {
        selfPasteChangeCount = NSPasteboard.general.changeCount
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    var modelContext: ModelContext? {
        didSet {
            loadFromSwiftData()
        }
    }
    
    struct ClipboardEntry: Identifiable, Equatable {
        let id: UUID
        let content: String
        let timestamp: Date
        let isImage: Bool
        var binaryData: Data?
        var fileURL: String?
        let shortPreview: String
        let isCode: Bool
        /// True for placeholder recordings that are still being saved by macOS
        var isPending: Bool
        
        init(content: String, timestamp: Date, isImage: Bool, binaryData: Data?, fileURL: String?, id: UUID = UUID(), isPending: Bool = false) {
            self.id = id
            self.content = String(content.prefix(5000)) // Cap in-memory; full text in SwiftData
            self.timestamp = timestamp
            self.isImage = isImage
            self.binaryData = binaryData
            self.fileURL = fileURL
            self.isPending = isPending
            
            self.isCode = CodeDetector.isCode(content)
            
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstNewlineIndex = trimmed.firstIndex(of: "\n") {
                let firstLine = String(trimmed[..<firstNewlineIndex])
                self.shortPreview = firstLine.count > 200 ? String(firstLine.prefix(200)) + "…" : firstLine
            } else {
                self.shortPreview = trimmed.count > 200 ? String(trimmed.prefix(200)) + "…" : trimmed
            }
        }
    }
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    private func loadFromSwiftData() {
        guard let ctx = modelContext else { return }
        
        do {
            var descriptor = FetchDescriptor<PasteItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = maxItems
            let savedItems = try ctx.fetch(descriptor)
            
            // Map SwiftData models into the fast in-memory array used by the Hotkey Menu
            // Load binaryData for first 10 items (visible in hotkey panel), skip rest to save RAM
            items = savedItems.enumerated().map { index, item in
                ClipboardEntry(
                    content: item.decryptedContent,
                    timestamp: item.createdAt,
                    isImage: item.mediaType == "image",
                    binaryData: index < 10 ? item.binaryData : nil,
                    fileURL: item.fileURLString
                )
            }
            logger.info("Successfully loaded \(self.items.count) past items from SwiftData upon startup.")
            onChange?()
        } catch {
            logger.error("Failed to load historical pastes from SwiftData: \(error.localizedDescription)")
        }
    }
    
    func startMonitoring() {
        let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentCount = NSPasteboard.general.changeCount
            guard currentCount != self.lastChangeCount else { return }
            self.processClipboardChange(newCount: currentCount)
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
        logger.info("Clipboard monitoring started on .common runloop")
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // Background thread processing to avoid blocking 120Hz SwiftUI frames
    private nonisolated func processClipboardChange(newCount: Int) {
        // Read pasteboard on main thread to avoid crashes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pb = NSPasteboard.general
            
            var ExtractedContent = ""
            var ExtractedMediaType = "text"
            var ExtractedBinaryData: Data? = nil
            var ExtractedFileURL: String? = nil
            
            // 1. Check for File URLs — use safe string-based reading
            let fileURL: URL? = {
                if let urlStr = pb.string(forType: .fileURL), let url = URL(string: urlStr) {
                    return url
                }
                if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
                   let firstPath = filenames.first {
                    return URL(fileURLWithPath: firstPath)
                }
                return nil
            }()
            
            if let firstURL = fileURL {
                let pathExt = firstURL.pathExtension.lowercased()
                let imageExtensions = ["png", "jpg", "jpeg", "tiff", "gif", "heic", "webp"]
                let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"]
                
                // Skip screen recordings — ScreenshotMonitor handles these via Desktop polling
                if ScreenshotMonitor.isRecordingFile(firstURL.lastPathComponent) {
                    return
                }
                
                if imageExtensions.contains(pathExt),
                   let rawImg = NSImage(contentsOf: firstURL) {
                    
                    let img = rawImg.resizedToFit(maxWidth: 400)
                    if let tiff = img.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                        
                        ExtractedContent = firstURL.lastPathComponent
                        ExtractedMediaType = "image"
                        ExtractedBinaryData = jpegData
                        ExtractedFileURL = firstURL.absoluteString
                    } else {
                        ExtractedContent = firstURL.lastPathComponent
                        ExtractedMediaType = "file"
                        ExtractedFileURL = firstURL.absoluteString
                    }
                } else if videoExtensions.contains(pathExt) {
                    ExtractedContent = firstURL.lastPathComponent
                    ExtractedMediaType = "file"
                    ExtractedFileURL = firstURL.absoluteString
                    
                    if let thumbData = Self.generateVideoThumbnail(url: firstURL) {
                        ExtractedBinaryData = thumbData
                    }
                    
                    // Cache video file for inline playback (sandbox access expires after capture)
                    Self.cacheVideoFile(from: firstURL)
                } else {
                    ExtractedContent = firstURL.lastPathComponent
                    ExtractedMediaType = "file"
                    ExtractedFileURL = firstURL.absoluteString
                }
            } 
            // 2. Check for pure Image Data (Screenshots, copied web images)
            // Use safe data-based reading instead of NSImage(pasteboard:)
            else if let tiffData = pb.data(forType: .tiff) {
                guard let rawImg = NSImage(data: tiffData) else { return }
                
                let img = rawImg.resizedToFit(maxWidth: 400)
                var jpegData: Data? = nil
                
                if let tiff = img.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                    jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6])
                } 
                
                if jpegData == nil {
                    var rect = NSRect(origin: .zero, size: img.size)
                    if let cgImage = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                        let newRep = NSBitmapImageRep(cgImage: cgImage)
                        jpegData = newRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])
                    }
                }
                
                if let jpegData = jpegData {
                    ExtractedContent = "Screenshot"
                    ExtractedMediaType = "image"
                    ExtractedBinaryData = jpegData
                } else {
                    return
                }
            } 
            // Also check for PNG data
            else if let pngData = pb.data(forType: .png) {
                guard let rawImg = NSImage(data: pngData) else { return }
                
                let img = rawImg.resizedToFit(maxWidth: 400)
                if let tiff = img.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                    ExtractedContent = "Screenshot"
                    ExtractedMediaType = "image"
                    ExtractedBinaryData = jpegData
                } else {
                    return
                }
            } 
            // 3. Fallback to standard String
            else if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ExtractedContent = string
                ExtractedMediaType = "text"
            } 
            else {
                // Unsupported or empty clipboard type
                return
            }
            
            // Already on main thread, save directly
            self.lastChangeCount = newCount
            self.saveProcessedItem(content: ExtractedContent, mediaType: ExtractedMediaType, binaryData: ExtractedBinaryData, fileURL: ExtractedFileURL)
        }
    }
    
    func saveProcessedItem(content finalContent: String, mediaType finalMediaType: String, binaryData finalBinaryData: Data?, fileURL finalFileURL: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Skip items that Pasty itself pasted (prevents re-ordering the list)
            if self.selfPasteChangeCount == NSPasteboard.general.changeCount {
                self.selfPasteChangeCount = -1
                return
            }
            
            let entry = ClipboardEntry(
                content: finalContent, 
                timestamp: Date(), 
                isImage: finalMediaType == "image",
                binaryData: finalBinaryData,
                fileURL: finalFileURL
            )
            self.items.insert(entry, at: 0)
            
            // Trim to max
            if self.items.count > self.maxItems {
                self.items = Array(self.items.prefix(self.maxItems))
            }
            // Release thumbnail RAM for items beyond visible range
            if self.items.count > 15 {
                for i in 15..<self.items.count where self.items[i].binaryData != nil {
                    self.items[i].binaryData = nil
                }
            }
            
            self.onChange?()
            self.logger.info("Clipboard captured: \(finalContent.prefix(40)) [\(finalMediaType)]")
        
            // Persist to SwiftData so it appears in History tab
            guard let ctx = self.modelContext else {
                self.logger.error("modelContext is nil — clipboard items won't persist to History")
                return
            }
        
            // Check for duplicate in SwiftData too
            var recentDescriptor = FetchDescriptor<PasteItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            recentDescriptor.fetchLimit = 1
            if let recent = try? ctx.fetch(recentDescriptor).first {
                if finalMediaType == "text" && recent.decryptedContent == finalContent {
                    self.logger.debug("Skipping SwiftData save — duplicate of most recent item")
                    return
                } else if finalMediaType == "image" && recent.binaryData == finalBinaryData {
                    self.logger.debug("Skipping SwiftData save — duplicate of most recent image")
                    return
                } else if finalMediaType == "file" && recent.fileURLString == finalFileURL {
                    self.logger.debug("Skipping SwiftData save — duplicate of most recent file")
                    return
                }
            }
        
            // Check if encryption is enabled (Only encrypt text)
            let secureHistory = UserDefaults.standard.bool(forKey: "secureHistory")
            
            let contentToStore: String
            let encrypted: Bool
            
            if secureHistory && finalMediaType == "text" {
                do {
                    contentToStore = try EncryptionService.shared.encrypt(finalContent)
                    encrypted = true
                    self.logger.info("Encrypted clipboard text content before saving")
                } catch {
                    self.logger.error("Encryption failed, saving plaintext: \(error.localizedDescription)")
                    contentToStore = finalContent
                    encrypted = false
                }
            } else {
                contentToStore = finalContent
                encrypted = false
            }
        
            let pasteItem = PasteItem(
                content: contentToStore,
                isPlainText: finalMediaType == "text",
                mediaType: finalMediaType,
                binaryData: finalBinaryData,
                fileURLString: finalFileURL
            )
            pasteItem.isEncrypted = encrypted
            
            if finalMediaType == "text" {
                pasteItem.title = PasteItem.generateTitle(from: finalContent)
            } else {
                pasteItem.title = finalContent
            }
            
            ctx.insert(pasteItem)
            
            do {
                try ctx.save()
                self.logger.info("Saved to SwiftData [\(finalMediaType)]: \(finalContent.prefix(30))")
            } catch {
                self.logger.error("Failed to save to SwiftData: \(error.localizedDescription)")
            }
        
            // Enforce history limit
            let allDescriptor = FetchDescriptor<PasteItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let all = try? ctx.fetch(allDescriptor), all.count > self.maxItems {
                for item in all.dropFirst(self.maxItems) {
                    ctx.delete(item)
                }
                try? ctx.save()
            }
        }
    }
    
    // MARK: - Recording Placeholder System
    
    /// Adds a placeholder entry for a screen recording that's still being saved by macOS.
    /// Saved to SwiftData immediately with isPending=true so it appears in the view with a loading overlay.
    func addPlaceholderRecording(id: UUID) {
        guard let ctx = modelContext else {
            logger.warning("No model context for placeholder")
            return
        }
        
        let pasteItem = PasteItem(
            content: "Screen Recording (saving...)",
            title: "Screen Recording (saving...)",
            mediaType: "file"
        )
        pasteItem.id = id
        pasteItem.isPending = true
        
        ctx.insert(pasteItem)
        try? ctx.save()
        onChange?()
        logger.info("Added recording placeholder to SwiftData")
    }
    
    /// Removes any stuck "Saving..." placeholder entries from previous sessions
    func removeStuckPlaceholders() {
        guard let ctx = modelContext else { return }
        
        let descriptor = FetchDescriptor<PasteItem>(
            predicate: #Predicate { $0.isPending == true }
        )
        
        guard let pending = try? ctx.fetch(descriptor), !pending.isEmpty else { return }
        
        for item in pending {
            ctx.delete(item)
        }
        try? ctx.save()
        
        // Also remove from in-memory items
        items.removeAll { $0.content.contains("(saving") }
        
        onChange?()
        logger.info("Cleaned up \(pending.count) stuck placeholder(s)")
    }
    
    /// Updates a placeholder entry with the real file data once the recording lands on Desktop.
    func updatePlaceholderRecording(id: UUID, url: URL) {
        guard let ctx = modelContext else {
            processExternalScreenshot(url: url)
            return
        }
        
        // Find ANY pending placeholder (don't rely on UUID match alone)
        let descriptor = FetchDescriptor<PasteItem>(
            predicate: #Predicate { $0.isPending == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        guard let pendingItem = try? ctx.fetch(descriptor).first else {
            // No placeholder found — process as new
            logger.warning("No pending placeholder found — adding as new entry")
            processExternalScreenshot(url: url)
            return
        }
        
        // Generate thumbnail
        let pathExt = url.pathExtension.lowercased()
        var thumbData: Data? = nil
        if ["mov", "mp4", "m4v"].contains(pathExt) {
            thumbData = Self.generateVideoThumbnail(url: url)
            Self.cacheVideoFile(from: url)
        }
        
        // Update the placeholder with real data
        pendingItem.content = url.lastPathComponent
        pendingItem.title = url.lastPathComponent
        pendingItem.binaryData = thumbData
        pendingItem.fileURLString = url.absoluteString
        pendingItem.isPending = false
        
        try? ctx.save()
        
        // Also update in-memory items array
        let entry = ClipboardEntry(
            content: url.lastPathComponent,
            timestamp: Date(),
            isImage: false,
            binaryData: thumbData,
            fileURL: url.absoluteString
        )
        // Replace the placeholder in items array if it exists
        if let idx = items.firstIndex(where: { $0.content.contains("Screen Recording (saving") }) {
            items[idx] = entry
        }
        
        onChange?()
        logger.info("Updated recording placeholder with real file: \(url.lastPathComponent)")
    }
    
    func processExternalScreenshot(url: URL) {
        let pathExt = url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "tiff", "gif", "heic", "webp"]
        let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"]
        
        var extractedContent = url.lastPathComponent
        var extractedMediaType = "file"
        var extractedBinaryData: Data? = nil
        let extractedFileURL = url.absoluteString
        
        if imageExtensions.contains(pathExt), let rawImg = NSImage(contentsOf: url) {
            let img = rawImg.resizedToFit(maxWidth: 800)
            var jpegData: Data? = nil
            
            if let tiff = img.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
            } 
            if jpegData == nil {
                var rect = NSRect(origin: .zero, size: img.size)
                if let cgImage = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                    let newRep = NSBitmapImageRep(cgImage: cgImage)
                    jpegData = newRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                }
            }
            
            if let jpegData = jpegData {
                extractedContent = "Screenshot"
                extractedMediaType = "image"
                extractedBinaryData = jpegData
            }
        } else if videoExtensions.contains(pathExt) {
            if let thumbData = Self.generateVideoThumbnail(url: url) {
                extractedBinaryData = thumbData
            }
            Self.cacheVideoFile(from: url)
        }
        
        self.saveProcessedItem(content: extractedContent, mediaType: extractedMediaType, binaryData: extractedBinaryData, fileURL: extractedFileURL)
    }
    
    func paste(_ entry: ClipboardEntry) {
        // Find the actual full-fidelity PasteItem from SwiftData
        guard let ctx = modelContext else {
            logger.warning("No model context — falling back to raw string paste")
            return doRawStringPaste(entry.content)
        }
        
        let targetContent = entry.content
        let descriptor = FetchDescriptor<PasteItem>(
            predicate: #Predicate { $0.content == targetContent },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        guard let savedItem = try? ctx.fetch(descriptor).first else {
            logger.warning("No SwiftData match for '\(targetContent)' — falling back to raw string paste")
            return doRawStringPaste(entry.content)
        }
        
        NSPasteboard.general.clearContents()
        
        if savedItem.mediaType == "file", let fileURLStr = savedItem.fileURLString {
            writeFileToPasteboard(fileURLStr)
        } 
        else if savedItem.mediaType == "image", let data = savedItem.binaryData, let nsImage = NSImage(data: data) {
            // Write both raw image data (for apps like Messages/Slack) AND a temp file URL (for Finder)
            let pb = NSPasteboard.general
            
            // 1. Write raw image so rich apps can use it
            pb.writeObjects([nsImage])
            
            // 2. Also write a temp PNG file URL so Finder can paste it as a real file
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "Pasty_Screenshot_\(Int(Date().timeIntervalSince1970)).png"
            let tempURL = tempDir.appendingPathComponent(filename)
            
            if let tiff = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempURL)
                
                // Add file URL types alongside the image data already on the pasteboard
                pb.addTypes([.fileURL], owner: nil)
                pb.setString(tempURL.absoluteString, forType: .fileURL)
                pb.addTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
                pb.setPropertyList([tempURL.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
            }
        } 
        else {
            NSPasteboard.general.setString(savedItem.decryptedContent, forType: .string)
        }
        
        lastChangeCount = NSPasteboard.general.changeCount
        selfPasteChangeCount = NSPasteboard.general.changeCount
        triggerCmdV()
    }
    
    /// Write a file URL to the pasteboard with full fidelity.
    /// Uses writeObjects (NSURL) for chat app compatibility + NSFilenamesPboardType for Finder.
    /// Requires ad-hoc signed binary to create sandbox extensions.
    private func writeFileToPasteboard(_ fileURLStr: String) {
        let url: URL
        if fileURLStr.hasPrefix("file://") {
            url = URL(string: fileURLStr) ?? URL(fileURLWithPath: fileURLStr.replacingOccurrences(of: "file://", with: ""))
        } else {
            url = URL(fileURLWithPath: fileURLStr)
        }
        
        let pb = NSPasteboard.general
        let path = url.path
        
        // writeObjects with NSURL creates sandbox extensions for receiving apps (Messages, browsers)
        pb.writeObjects([url as NSURL])
        
        // Also add legacy NSFilenamesPboardType for Finder compatibility
        pb.addTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
        pb.setPropertyList([path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        
        if FileManager.default.fileExists(atPath: path) {
            logger.info("File pasted: \(path)")
        } else {
            logger.warning("File not found at path: \(path)")
        }
    }
    
    private func doRawStringPaste(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        triggerCmdV()
    }
    
    private func triggerCmdV() {
        // Simulate Cmd+V after delay — give previous app time to regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let src = CGEventSource(stateID: .hidSystemState)
            
            // Key down
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // V
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            
            // Key up
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)
        }
    }
    

    func remove(_ entry: ClipboardEntry) {
        items.removeAll { $0.id == entry.id }
    }
    
    func bringToTop(_ entry: ClipboardEntry) {
        items.removeAll { $0.id == entry.id }
        let newEntry = ClipboardEntry(
            content: entry.content, 
            timestamp: Date(), 
            isImage: entry.isImage,
            binaryData: entry.binaryData,
            fileURL: entry.fileURL
        )
        items.insert(newEntry, at: 0)
        onChange?()
    }
    
    func clearAll() {
        items.removeAll()
    }
    
    /// Generate a JPEG thumbnail from a video file (single frame, RAM-light)
    static func generateVideoThumbnail(url: URL, maxWidth: CGFloat = 300) -> Data? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            guard let tiff = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else {
                return nil
            }
            return jpegData
        } catch {
            return nil
        }
    }
    
    // MARK: - Video Cache (for inline playback)
    
    /// Directory for cached video files
    static var videoCacheDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Pasty/VideoCache", isDirectory: true)
    }
    
    /// Copy a video file to the cache during capture (while pasteboard access is active)
    static func cacheVideoFile(from url: URL) {
        let cacheDir = videoCacheDir
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }
    
    /// Get the cached path for a file (returns nil if not cached)
    static func cachedVideoPath(for filename: String) -> URL? {
        let cached = videoCacheDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: cached.path) ? cached : nil
    }
}

