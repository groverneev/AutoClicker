import AppKit
import ApplicationServices

/// Posting synthetic mouse events to other apps requires the Accessibility permission.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that offers to open System Settings › Accessibility.
    static func requestAccess() {
        // Literal value of kAXTrustedCheckOptionPrompt (the global isn't concurrency-safe in Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
