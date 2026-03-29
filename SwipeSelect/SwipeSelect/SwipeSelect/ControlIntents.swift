import AppIntents
import WidgetKit

// Shared helper for reading/writing prefs from any process
enum SharedPrefs {
    static let suiteName = "group.J.SwipeSelect"
    
    static func read(_ key: String, default defaultValue: Bool = false) -> Bool {
        UserDefaults(suiteName: suiteName)?.bool(forKey: key) ?? defaultValue
    }
    
    static func readString(_ key: String, default defaultValue: String) -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: key) ?? defaultValue
    }
    
    static func write(_ key: String, value: Bool) {
        UserDefaults(suiteName: suiteName)?.set(value, forKey: key)
    }
    
    static func write(_ key: String, value: String) {
        UserDefaults(suiteName: suiteName)?.set(value, forKey: key)
    }
}

// MARK: - Engine Toggle

struct ToggleEngineIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle SwipeSelect Engine"
    
    @Parameter(title: "Enabled")
    var value: Bool
    
    func perform() async throws -> some IntentResult {
        SharedPrefs.write("engineEnabled", value: value)
        return .result()
    }
}

struct EngineValueProvider: ControlValueProvider {
    func currentValue() async throws -> Bool {
        let defaults = UserDefaults(suiteName: SharedPrefs.suiteName)
        if defaults?.object(forKey: "engineEnabled") == nil { return true }
        return defaults?.bool(forKey: "engineEnabled") ?? true
    }
    var previewValue: Bool { true }
}

// MARK: - Switch Mode

struct SwitchModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Cursor Mode"
    
    func perform() async throws -> some IntentResult {
        let current = SharedPrefs.readString("cursorMode", default: "freeGlide")
        SharedPrefs.write("cursorMode", value: current == "freeGlide" ? "ogSwipeSelection" : "freeGlide")
        return .result()
    }
}

// MARK: - Double-Tap Select Toggle

struct ToggleDoubleTapIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Double-Tap Select"
    
    @Parameter(title: "Enabled")
    var value: Bool
    
    func perform() async throws -> some IntentResult {
        SharedPrefs.write("doubleTapSelectEnabled", value: value)
        return .result()
    }
}

struct DoubleTapValueProvider: ControlValueProvider {
    func currentValue() async throws -> Bool {
        SharedPrefs.read("doubleTapSelectEnabled")
    }
    var previewValue: Bool { false }
}

// MARK: - Shake to Undo Toggle

struct ToggleShakeUndoIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Shake to Undo"
    
    @Parameter(title: "Enabled")
    var value: Bool
    
    func perform() async throws -> some IntentResult {
        SharedPrefs.write("shakeToUndoEnabled", value: value)
        return .result()
    }
}

struct ShakeUndoValueProvider: ControlValueProvider {
    func currentValue() async throws -> Bool {
        SharedPrefs.read("shakeToUndoEnabled")
    }
    var previewValue: Bool { false }
}
