import Foundation
import os.log

/// Centralized logging using Apple's os.Logger
enum PastyLogger {
    static let network = Logger(subsystem: "com.pasty.app", category: "network")
    static let clipboard = Logger(subsystem: "com.pasty.app", category: "clipboard")
    static let security = Logger(subsystem: "com.pasty.app", category: "security")
    static let ui = Logger(subsystem: "com.pasty.app", category: "ui")
    static let system = Logger(subsystem: "com.pasty.app", category: "system")
    static let data = Logger(subsystem: "com.pasty.app", category: "data")
}
