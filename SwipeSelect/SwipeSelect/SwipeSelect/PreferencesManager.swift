import SwiftUI
import Combine

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    // Use standard defaults for now — App Group only needed when
    // we add a real Widget Extension target later.
    private let defaults = UserDefaults.standard
    
    // ─── Core Engine ───
    @Published var engineEnabled: Bool {
        didSet { defaults.set(engineEnabled, forKey: "engineEnabled") }
    }
    
    // ─── Cursor Mode ───
    @Published var cursorMode: String {
        didSet { defaults.set(cursorMode, forKey: "cursorMode") }
    }
    
    // ─── Sensitivity ───
    @Published var glideSpeed: Double {
        didSet { defaults.set(glideSpeed, forKey: "glideSpeed") }
    }
    @Published var ogSensitivity: Double {
        didSet { defaults.set(ogSensitivity, forKey: "ogSensitivity") }
    }
    @Published var glideEndDelay: Double {
        didSet { defaults.set(glideEndDelay, forKey: "glideEndDelay") }
    }
    
    // ─── Pure Trackpad Features (OFF by default) ───
    @Published var doubleTapSelectEnabled: Bool {
        didSet { defaults.set(doubleTapSelectEnabled, forKey: "doubleTapSelectEnabled") }
    }
    
    private init() {
        defaults.register(defaults: [
            "engineEnabled": true,
            "cursorMode": "freeGlide",
            "glideSpeed": 2.5,
            "ogSensitivity": 4.0,
            "glideEndDelay": 0.25,
            "doubleTapSelectEnabled": true,
        ])
        
        self.engineEnabled = defaults.bool(forKey: "engineEnabled")
        self.cursorMode = defaults.string(forKey: "cursorMode") ?? "freeGlide"
        self.glideSpeed = defaults.double(forKey: "glideSpeed")
        self.ogSensitivity = defaults.double(forKey: "ogSensitivity")
        self.glideEndDelay = defaults.double(forKey: "glideEndDelay")
        self.doubleTapSelectEnabled = defaults.bool(forKey: "doubleTapSelectEnabled")
        
        if self.glideSpeed == 0 { self.glideSpeed = 2.5 }
        if self.ogSensitivity == 0 { self.ogSensitivity = 4.0 }
        if self.glideEndDelay == 0 { self.glideEndDelay = 0.25 }
        
        // Migration: old App Group prefs stored false, force-enable
        if !defaults.bool(forKey: "v2_migrated") {
            self.doubleTapSelectEnabled = true
            defaults.set(true, forKey: "v2_migrated")
        }
    }
}
