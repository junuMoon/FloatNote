import Carbon
import Foundation

final class HotKeyMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: 0x464e4f54, id: 1)

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let monitor = Unmanaged<HotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                return monitor.handle(event: event)
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        )
    }

    deinit {
        unregister()

        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func register(shortcut: KeyShortcut, callback: @escaping () -> Void) {
        unregister()
        self.callback = callback

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("Failed to register hotkey: \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handle(event: EventRef) -> OSStatus {
        var eventID = EventHotKeyID()

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventID
        )

        guard status == noErr else {
            return status
        }

        guard eventID.id == hotKeyID.id && eventID.signature == hotKeyID.signature else {
            return OSStatus(eventNotHandledErr)
        }

        callback?()
        return noErr
    }
}
