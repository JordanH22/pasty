import Foundation
import Sparkle

/// Manages Sparkle auto-updates for Pasty.
/// Checks for updates on launch and provides a manual "Check for Updates" action.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()
    
    let updaterController: SPUStandardUpdaterController
    
    private init() {
        // Initialize Sparkle with standard UI and no delegate initially
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    /// The updater instance for SwiftUI bindings
    var updater: SPUUpdater {
        updaterController.updater
    }
    
    /// Check for updates manually (e.g. from Settings)
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    /// Whether the "Check for Updates" action is currently available
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}
