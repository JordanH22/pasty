import SwiftUI


@Observable
final class AppState {
    // MARK: - UI State
    var selectedTab: PastyTab = .newPaste
    var isPopoverVisible: Bool = false
    var searchText: String = ""
    
    // MARK: - Popover Keyboard Navigation
    var popoverSelectedIndex: Int = 0
    var popoverKeyboardNavigating: Bool = false
    var popoverHoverEnabled: Bool = false
    var popoverItemCount: Int = 0
    
    // MARK: - Clipboard
    var currentClipboardContent: String = ""
    var lastChangeCount: Int = 0
    
    // MARK: - Network
    var isOnline: Bool = true
    var pendingUploadCount: Int = 0
    
    // MARK: - Persisted Settings (UserDefaults-backed)
    
    init() {
        // Clear any pre-configured paste service URL — user should set their own
        if let saved = Self.defaults.string(forKey: "pasteServiceURL"),
           (saved.contains("dpaste.org") || saved.contains("paste.rs")) {
            Self.defaults.removeObject(forKey: "pasteServiceURL")
            pasteServiceURL = ""
        }
    }
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    
    var defaultDestructTimer: DestructTimer {
        get { DestructTimer(rawValue: Self.defaults.string(forKey: "defaultDestructTimer") ?? DestructTimer.never.rawValue) ?? .never }
        set { Self.defaults.set(newValue.rawValue, forKey: "defaultDestructTimer") }
    }
    
    var plainTextByDefault: Bool {
        get { Self.defaults.bool(forKey: "plainTextByDefault") }
        set { Self.defaults.set(newValue, forKey: "plainTextByDefault") }
    }
    
    var autoCapture: Bool {
        get {
            if Self.defaults.object(forKey: "autoCapture") == nil { return true }
            return Self.defaults.bool(forKey: "autoCapture")
        }
        set { Self.defaults.set(newValue, forKey: "autoCapture") }
    }
    
    var historyLimit: Int {
        get {
            let val = Self.defaults.integer(forKey: "historyLimit")
            return val > 0 ? val : 50
        }
        set { Self.defaults.set(newValue, forKey: "historyLimit") }
    }
    
    var launchAtLogin: Bool {
        get { Self.defaults.bool(forKey: "launchAtLogin") }
        set { Self.defaults.set(newValue, forKey: "launchAtLogin") }
    }
    
    var showUploadButton: Bool = UserDefaults.standard.bool(forKey: "showUploadButton") {
        didSet { Self.defaults.set(showUploadButton, forKey: "showUploadButton") }
    }
    
    var secureHistory: Bool = UserDefaults.standard.bool(forKey: "secureHistory") {
        didSet { Self.defaults.set(secureHistory, forKey: "secureHistory") }
    }
    
    // MARK: - IDE Expanded View Settings
    
    var codeViewEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "codeViewEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "codeViewEnabled")
    }() {
        didSet { Self.defaults.set(codeViewEnabled, forKey: "codeViewEnabled") }
    }
    
    var syntaxHighlighting: Bool = {
        if UserDefaults.standard.object(forKey: "syntaxHighlighting") == nil { return true }
        return UserDefaults.standard.bool(forKey: "syntaxHighlighting")
    }() {
        didSet { Self.defaults.set(syntaxHighlighting, forKey: "syntaxHighlighting") }
    }
    
    var showLineNumbers: Bool = {
        if UserDefaults.standard.object(forKey: "showLineNumbers") == nil { return true }
        return UserDefaults.standard.bool(forKey: "showLineNumbers")
    }() {
        didSet { Self.defaults.set(showLineNumbers, forKey: "showLineNumbers") }
    }
    
    var showCopyLineButton: Bool = {
        if UserDefaults.standard.object(forKey: "showCopyLineButton") == nil { return true }
        return UserDefaults.standard.bool(forKey: "showCopyLineButton")
    }() {
        didSet { Self.defaults.set(showCopyLineButton, forKey: "showCopyLineButton") }
    }
    
    var pasteServiceURL: String = UserDefaults.standard.string(forKey: "pasteServiceURL") ?? "" {
        didSet { Self.defaults.set(pasteServiceURL, forKey: "pasteServiceURL") }
    }
    
    var popoverWidth: Double {
        get {
            let val = Self.defaults.double(forKey: "popoverWidth")
            return val > 0 ? val : 420
        }
        set { Self.defaults.set(newValue, forKey: "popoverWidth") }
    }
    
    var popoverHeight: Double {
        get {
            let val = Self.defaults.double(forKey: "popoverHeight")
            return val > 0 ? val : 520
        }
        set { Self.defaults.set(newValue, forKey: "popoverHeight") }
    }
    
    var hotkeyMenuWidth: Double {
        get {
            let val = Self.defaults.double(forKey: "hotkeyMenuWidth")
            return val > 0 ? val : 380
        }
        set { Self.defaults.set(newValue, forKey: "hotkeyMenuWidth") }
    }
    
    var hotkeyMenuHeight: Double {
        get {
            let val = Self.defaults.double(forKey: "hotkeyMenuHeight")
            return val > 0 ? val : 800
        }
        set { Self.defaults.set(newValue, forKey: "hotkeyMenuHeight") }
    }
    
    var accentColorHue: Double {
        get {
            if Self.defaults.object(forKey: "accentColorHue") == nil { return 0.6 }
            return Self.defaults.double(forKey: "accentColorHue")
        }
        set {
            Self.defaults.set(newValue, forKey: "accentColorHue")
            syncToiCloud("accentColorHue", value: newValue)
        }
    }
    
    var accentColor: Color {
        Color(hue: accentColorHue, saturation: 0.7, brightness: 0.9)
    }
    
    // MARK: - iCloud Key-Value Sync
    
    var iCloudSyncEnabled: Bool {
        get { Self.defaults.bool(forKey: "iCloudSyncEnabled") }
        set {
            Self.defaults.set(newValue, forKey: "iCloudSyncEnabled")
            if newValue {
                pushAllToiCloud()
                startObservingiCloud()
            }
        }
    }
    
    /// Keys that should sync across devices via iCloud
    private static let syncableKeys = [
        "accentColorHue", "secureHistory", "historyLimit",
        "codeViewEnabled", "syntaxHighlighting", "showLineNumbers",
        "showCopyLineButton", "plainTextByDefault", "autoCapture",
        "globalHotkey", "hotkeyMenuWidth", "hotkeyMenuHeight",
        "popoverWidth", "popoverHeight"
    ]
    
    private func syncToiCloud(_ key: String, value: Any) {
        guard Self.defaults.bool(forKey: "iCloudSyncEnabled") else { return }
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    private func pushAllToiCloud() {
        let store = NSUbiquitousKeyValueStore.default
        for key in Self.syncableKeys {
            if let value = Self.defaults.object(forKey: key) {
                store.set(value, forKey: key)
            }
        }
        store.synchronize()
    }
    
    func startObservingiCloud() {
        guard Self.defaults.bool(forKey: "iCloudSyncEnabled") else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            let store = NSUbiquitousKeyValueStore.default
            for key in changedKeys where Self.syncableKeys.contains(key) {
                if let value = store.object(forKey: key) {
                    Self.defaults.set(value, forKey: key)
                }
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

// MARK: - Enums

enum PastyTab: String, CaseIterable, Identifiable {
    case history = "History"
    case newPaste = "New Paste"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .history: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .newPaste: "plus.square.on.square"
        case .settings: "gearshape"
        }
    }
    
    var symbolFill: String {
        switch self {
        case .history: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .newPaste: "plus.square.on.square.fill"
        case .settings: "gearshape.fill"
        }
    }
}

enum DestructTimer: String, CaseIterable, Identifiable, Codable {
    case oneHour = "1 Hour"
    case oneDay = "1 Day"
    case oneWeek = "1 Week"
    case never = "Never"
    
    var id: String { rawValue }
    
    var seconds: Int? {
        switch self {
        case .oneHour: 3600
        case .oneDay: 86400
        case .oneWeek: 604800
        case .never: nil
        }
    }
    
    var apiValue: String {
        switch self {
        case .oneHour: "3600"
        case .oneDay: "86400"
        case .oneWeek: "604800"
        case .never: ""
        }
    }
}
