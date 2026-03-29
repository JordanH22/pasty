import Foundation
import Cocoa
import ApplicationServices
import SwiftUI
import Combine

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isTrusted: Bool = false
    
    private var pollTimer: Timer?
    
    private init() {
        isTrusted = AXIsProcessTrusted()
    }
    
    /// Triggers macOS to add this app to the Accessibility list and show the system prompt.
    /// Uses the exact same raw-string pattern proven in Pasty's OnboardingView.
    func promptAndOpen() {
        // Force macOS to add SwipeSelect to the Accessibility list quietly
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Then explicitly open the Accessibility pane so they can toggle it
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        
        // Start polling so UI auto-updates the moment they toggle it on
        startPolling()
    }
    
    /// Polls every 2 seconds to detect when the user grants Accessibility access.
    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                self?.isTrusted = trusted
            }
            if trusted {
                timer.invalidate()
                // Auto-start the engine the moment permissions are granted
                GlideEngine.shared.start()
            }
        }
    }
    
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
