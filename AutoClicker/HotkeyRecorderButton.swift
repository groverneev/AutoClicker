import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Shows the current shortcut; click it, then press a new key combination to change it.
struct HotkeyRecorderButton: View {
    @Bindable var model: AppModel
    @State private var monitor: Any?

    var body: some View {
        Button {
            model.isRecordingHotkey ? stopRecording() : startRecording()
        } label: {
            Text(model.isRecordingHotkey ? "Press shortcut…" : model.hotkey.displayString)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .contextMenu {
            Button("Reset to ⇧⌘S") { model.resetHotkey() }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        model.isRecordingHotkey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            if event.type == .leftMouseDown {
                // Clicking anywhere else cancels; let the click through.
                stopRecording()
                return event
            }
            if Int(event.keyCode) == kVK_Escape {
                stopRecording()
            } else if let hotkey = Hotkey(event: event) {
                model.hotkey = hotkey
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        model.isRecordingHotkey = false
    }
}
