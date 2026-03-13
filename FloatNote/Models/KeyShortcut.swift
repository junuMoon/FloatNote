import AppKit
import Carbon

struct ShortcutModifiers: OptionSet, Codable, Equatable {
    let rawValue: UInt

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(event: NSEvent) {
        var modifiers: ShortcutModifiers = []
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }

        self = modifiers
    }

    var carbonValue: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var symbols: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.joined()
    }
}

struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: ShortcutModifiers

    static let defaultToggle = KeyShortcut(
        keyCode: UInt16(kVK_ANSI_A),
        modifiers: [.control]
    )

    static let defaultPrevious = KeyShortcut(
        keyCode: UInt16(kVK_LeftArrow),
        modifiers: [.control, .shift]
    )

    static let defaultNext = KeyShortcut(
        keyCode: UInt16(kVK_RightArrow),
        modifiers: [.control, .shift]
    )

    static func from(event: NSEvent) -> KeyShortcut? {
        guard !modifierOnlyKeyCodes.contains(event.keyCode) else {
            return nil
        }

        return KeyShortcut(
            keyCode: event.keyCode,
            modifiers: ShortcutModifiers(event: event)
        )
    }

    func matches(_ event: NSEvent) -> Bool {
        keyCode == event.keyCode && modifiers == ShortcutModifiers(event: event)
    }

    var carbonModifiers: UInt32 {
        modifiers.carbonValue
    }

    var label: String {
        "\(modifiers.symbols)\(keyLabel(for: keyCode))"
    }
}

private let modifierOnlyKeyCodes: Set<UInt16> = [
    UInt16(kVK_Command),
    UInt16(kVK_Shift),
    UInt16(kVK_CapsLock),
    UInt16(kVK_Option),
    UInt16(kVK_Control),
    UInt16(kVK_RightShift),
    UInt16(kVK_RightOption),
    UInt16(kVK_RightControl),
    UInt16(kVK_Function)
]

private func keyLabel(for keyCode: UInt16) -> String {
    switch Int(keyCode) {
    case kVK_ANSI_A: return "A"
    case kVK_ANSI_B: return "B"
    case kVK_ANSI_C: return "C"
    case kVK_ANSI_D: return "D"
    case kVK_ANSI_E: return "E"
    case kVK_ANSI_F: return "F"
    case kVK_ANSI_G: return "G"
    case kVK_ANSI_H: return "H"
    case kVK_ANSI_I: return "I"
    case kVK_ANSI_J: return "J"
    case kVK_ANSI_K: return "K"
    case kVK_ANSI_L: return "L"
    case kVK_ANSI_M: return "M"
    case kVK_ANSI_N: return "N"
    case kVK_ANSI_O: return "O"
    case kVK_ANSI_P: return "P"
    case kVK_ANSI_Q: return "Q"
    case kVK_ANSI_R: return "R"
    case kVK_ANSI_S: return "S"
    case kVK_ANSI_T: return "T"
    case kVK_ANSI_U: return "U"
    case kVK_ANSI_V: return "V"
    case kVK_ANSI_W: return "W"
    case kVK_ANSI_X: return "X"
    case kVK_ANSI_Y: return "Y"
    case kVK_ANSI_Z: return "Z"
    case kVK_ANSI_0: return "0"
    case kVK_ANSI_1: return "1"
    case kVK_ANSI_2: return "2"
    case kVK_ANSI_3: return "3"
    case kVK_ANSI_4: return "4"
    case kVK_ANSI_5: return "5"
    case kVK_ANSI_6: return "6"
    case kVK_ANSI_7: return "7"
    case kVK_ANSI_8: return "8"
    case kVK_ANSI_9: return "9"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    case kVK_Escape: return "Esc"
    case kVK_Space: return "Space"
    case kVK_Return: return "Return"
    case kVK_ANSI_LeftBracket: return "["
    case kVK_ANSI_RightBracket: return "]"
    case kVK_ANSI_Comma: return ","
    case kVK_ANSI_Period: return "."
    case kVK_ANSI_Slash: return "/"
    default: return "Key \(keyCode)"
    }
}
