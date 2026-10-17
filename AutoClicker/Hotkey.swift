import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut, stored with Carbon key code and modifier flags.
struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String

    static let defaultShortcut = Hotkey(
        keyCode: UInt32(kVK_ANSI_S),
        carbonModifiers: UInt32(cmdKey | shiftKey),
        keyLabel: "S"
    )

    var displayString: String {
        displayKeys.joined()
    }

    /// Modifier symbols in the standard macOS order, followed by the key.
    var displayKeys: [String] {
        var keys: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { keys.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { keys.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { keys.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { keys.append("⌘") }
        return keys + [keyLabel]
    }

    /// Builds a hotkey from a key-down event, or returns `nil` if the combination isn't usable
    /// as a global shortcut (plain keys need at least one modifier; function keys don't).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }

        let code = Int(event.keyCode)
        let isFunctionKey = Self.functionKeys[code] != nil
        if modifiers & UInt32(cmdKey | optionKey | controlKey) == 0 && !isFunctionKey {
            return nil
        }

        let label = Self.functionKeys[code]
            ?? Self.specialKeys[code]
            ?? event.characters(byApplyingModifiers: [])?.uppercased()
        guard let label, !label.isEmpty else { return nil }

        self.init(keyCode: UInt32(code), carbonModifiers: modifiers, keyLabel: label)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    ]
}

extension Hotkey {
    private static let defaultsKey = "hotkey"

    static func load() -> Hotkey {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data)
        else { return .defaultShortcut }
        return hotkey
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// Registers a single system-wide hotkey through Carbon. Works while the app is in the
/// background and doesn't require any extra permission.
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    private init() {}

    func register(_ hotkey: Hotkey?) {
        unregister()
        guard let hotkey else { return }
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(0x4143_4C4B) /* 'ACLK' */, id: 1)
        RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers, id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated {
                HotkeyCenter.shared.onPress?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
