import AppKit
import Carbon

// MARK: - Hotkey Manager

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeys: [UInt32: HotkeyRegistration] = [:]
    private var nextId: UInt32 = 1

    private init() {}

    struct HotkeyRegistration {
        let id: UInt32
        let hotkey: HotkeyConfig
        let handler: () -> Void
        var eventHotKeyRef: EventHotKeyRef?
    }

    func register(hotkey: HotkeyConfig, handler: @escaping () -> Void) {
        let id = nextId
        nextId += 1

        var registration = HotkeyRegistration(id: id, hotkey: hotkey, handler: handler)

        // Install Carbon event handler on first registration
        if hotkeys.isEmpty {
            installCarbonHandler()
        }

        // Register the hotkey with Carbon
        var eventHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x414C4D45), id: id) // "ALME"
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKeyRef
        )

        if status == noErr {
            registration.eventHotKeyRef = eventHotKeyRef
            hotkeys[id] = registration
            print("✅ Hotkey registered (id: \(id))")
        } else {
            print("❌ Failed to register hotkey: \(status)")
        }
    }

    func unregisterAll() {
        for (_, registration) in hotkeys {
            if let ref = registration.eventHotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotkeys.removeAll()
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                HotkeyManager.shared.handleHotkey(id: hotKeyID.id)
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
    }

    fileprivate func handleHotkey(id: UInt32) {
        if let registration = hotkeys[id] {
            DispatchQueue.main.async {
                registration.handler()
            }
        }
    }
}
