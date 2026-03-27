import Cocoa
import Carbon
import os.log

enum GlobalHotkey: String, CaseIterable, Identifiable {
    case optV = "optV"
    case cmdShiftV = "cmdShiftV"
    case cmdOptV = "cmdOptV"
    case ctrlCmdV = "ctrlCmdV"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .optV: return "⌥ V"
        case .cmdShiftV: return "⌘ ⇧ V"
        case .cmdOptV: return "⌘ ⌥ V"
        case .ctrlCmdV: return "⌃ ⌘ V"
        }
    }
    
    var description: String {
        switch self {
        case .optV: return "The Absolute Fastest"
        case .cmdShiftV: return "The Classic Default"
        case .cmdOptV: return "The Power User"
        case .ctrlCmdV: return "The Safe Route"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .optV: return "By dropping the 'Command' key, Option+V is mathematically the fastest shortcut to trigger with one hand. Ideal for extreme power users who demand zero input latency."
        case .cmdShiftV: return "The traditional standard. It's safe, highly memorable, and doesn't conflict with most applications, but physically requires awkwardly contorting three fingers."
        case .cmdOptV: return "A highly ergonomic middle ground. Very easy to strike rapidly with your thumb and index finger without breaking your typing stance."
        case .ctrlCmdV: return "The ultimate anti-collision shortcut. If you have complex macro workflows inside IDEs or Photoshop, this will never accidentally trigger their bindings."
        }
    }
    
    var modifiers: UInt32 {
        switch self {
        case .optV: return UInt32(optionKey)
        case .cmdShiftV: return UInt32(cmdKey | shiftKey)
        case .cmdOptV: return UInt32(cmdKey | optionKey)
        case .ctrlCmdV: return UInt32(controlKey | cmdKey)
        }
    }
    
    var keyCode: UInt32 {
        return 9 // 'V' is keyCode 9
    }
}

final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()
    
    private let logger = Logger(subsystem: "com.pasty.app", category: "hotkey")
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    var onToggle: (() -> Void)?
    
    private init() {}
    
    // MARK: - Carbon Hotkey Registration (most reliable, no accessibility needed)
    
    func register() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x50535459), id: 1)
        
        let savedValue = UserDefaults.standard.string(forKey: "globalHotkey") ?? GlobalHotkey.cmdShiftV.rawValue
        let selectedHotkey = GlobalHotkey(rawValue: savedValue) ?? .cmdShiftV
        
        let modifiers: UInt32 = selectedHotkey.modifiers
        let keyCode: UInt32 = selectedHotkey.keyCode
        
        // Install event handler ONLY if not already installed
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                carbonHotkeyCallback,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
            guard status == noErr else {
                logger.error("Failed to install hotkey event handler: \(status)")
                return
            }
        }
        
        // Unregister previous hotkey if swapping
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        // Register the new hotkey
        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if regStatus == noErr {
            logger.info("Global hotkey registered: \(selectedHotkey.title) (Carbon)")
        } else {
            logger.error("Failed to register hotkey: \(regStatus)")
        }
    }
    
    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        logger.info("Global hotkey unregistered")
    }
    
    func reload() {
        register()
    }
    
    // MARK: - Callback
    
    fileprivate func handleHotkeyTriggered() {
        DispatchQueue.main.async { [weak self] in
            self?.onToggle?()
        }
    }
}

// Carbon callback — must be a free function, not a closure
private func carbonHotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkeyTriggered()
    return noErr
}
