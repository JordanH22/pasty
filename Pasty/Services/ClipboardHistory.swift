import Foundation
import AppKit
import AVFoundation
import SwiftData
import os.log

extension NSImage {
    /// Deep-levels the NSImage geometry bounds to a strict max constraint to physically gate RAM decompression buffers
    func resizedToFit(maxWidth: CGFloat) -> NSImage {
        guard self.size.width > maxWidth else { return self }
        let scale = maxWidth / self.size.width
        let newSize = NSSize(width: maxWidth, height: self.size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

@MainActor
final class ClipboardHistory: @unchecked Sendable {
    static let shared = ClipboardHistory()
    
    private let logger = Logger(subsystem: "com.pasty.app", category: "clipboard-history")
    private var timer: Timer?
    private var lastChangeCount: Int
    
    private(set) var items: [ClipboardEntry] = []
    var maxItems: Int = 50
    var onChange: (() -> Void)?
    
    var modelContext: ModelContext? {
        didSet {
            loadFromSwiftData()
        }
    }
    
    struct ClipboardEntry: Identifiable, Equatable {
        let id = UUID()
        let content: String
        let timestamp: Date
        let isImage: Bool
        let binaryData: Data?
        let fileURL: String?
        let shortPreview: String
        let isCode: Bool
        
        init(content: String, timestamp: Date, isImage: Bool, binaryData: Data?, fileURL: String?) {
            self.content = content
            self.timestamp = timestamp
            self.isImage = isImage
            self.binaryData = binaryData
            self.fileURL = fileURL
            
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
            let descriptor = FetchDescriptor<PasteItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let savedItems = try ctx.fetch(descriptor)
            
            // Map the SwiftData models back into the fast in-memory array used by the Hotkey Menu
            items = savedItems.prefix(maxItems).map { item in
                ClipboardEntry(
                    content: item.decryptedContent,
                    timestamp: item.createdAt,
                    isImage: item.mediaType == "image",
                    binaryData: item.binaryData,
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
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentCount = NSPasteboard.general.changeCount
            guard currentCount != self.lastChangeCount else { return }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processClipboardChange(newCount: currentCount)
            }
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
    private func processClipboardChange(newCount: Int) {
        let pb = NSPasteboard.general
        
        var ExtractedContent = ""
        var ExtractedMediaType = "text"
        var ExtractedBinaryData: Data? = nil
        var ExtractedFileURL: String? = nil
        
        // 1. Check for File URLs — use direct type reading to avoid sandbox extension errors
        let fileURL: URL? = {
            // Try legacy NSFilenamesPboardType first (Finder uses this)
            if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
               let firstPath = filenames.first {
                return URL(fileURLWithPath: firstPath)
            }
            // Try modern public.file-url
            if let urlStr = pb.string(forType: .fileURL), let url = URL(string: urlStr) {
                return url
            }
            return nil
        }()
        
        if let firstURL = fileURL {
            let pathExt = firstURL.pathExtension.lowercased()
            let imageExtensions = ["png", "jpg", "jpeg", "tiff", "gif", "heic", "webp"]
            let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpeg", "mpg"]
            
            if imageExtensions.contains(pathExt),
               let rawImg = NSImage(contentsOf: firstURL) {
                
                let img = rawImg.resizedToFit(maxWidth: 800)
                if let tiff = img.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    
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
        else if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], 
                let rawImg = images.first {
            
            let img = rawImg.resizedToFit(maxWidth: 800)
            if let tiff = img.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                
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
        // Now switch back to the Main Thread for UI and SwiftData updates
        DispatchQueue.main.async { [weak self, 
                                    finalContent = ExtractedContent, 
                                    finalMediaType = ExtractedMediaType, 
                                    finalBinaryData = ExtractedBinaryData, 
                                    finalFileURL = ExtractedFileURL] in
            guard let self = self else { return }
            
            // Advance the change count now that processing is secure
            self.lastChangeCount = newCount
            
            // Don't add duplicates of the most recent item (based on content title, or raw string)
            if let last = self.items.first, last.content == finalContent { return }
            
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
            
            self.onChange?()
            self.logger.info("Clipboard captured: \(finalContent.prefix(40)) [\(finalMediaType)]")
        
            // Persist to SwiftData so it appears in History tab
            guard let ctx = self.modelContext else {
                self.logger.error("modelContext is nil — clipboard items won't persist to History")
                return
            }
        
            // Check for duplicate in SwiftData too
            let recentDescriptor = FetchDescriptor<PasteItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let recent = try? ctx.fetch(recentDescriptor).first,
               recent.decryptedContent == finalContent {
                self.logger.debug("Skipping SwiftData save — duplicate of most recent item")
                return
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
        } // End of Main Thread Dispatch
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
            NSPasteboard.general.writeObjects([nsImage])
        } 
        else {
            NSPasteboard.general.setString(savedItem.decryptedContent, forType: .string)
        }
        
        lastChangeCount = NSPasteboard.general.changeCount
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
    static func generateVideoThumbnail(url: URL, maxWidth: CGFloat = 400) -> Data? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            guard let tiff = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
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

