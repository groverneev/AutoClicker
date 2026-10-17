import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Shows the current shortcut as keycaps; click it, then press a new key combination to change it.
struct HotkeyRecorderButton: View {
    @Bindable var model: AppModel
    @State private var monitor: Any?
    @State private var isHovering = false

    var body: some View {
        Button {
            model.isRecordingHotkey ? stopRecording() : startRecording()
        } label: {
            HStack(spacing: 6) {
                if model.isRecordingHotkey {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                    Text("Type a shortcut…")
                        .foregroundStyle(.primary)
                } else {
                    HStack(spacing: 3) {
                        ForEach(Array(model.hotkey.displayKeys.enumerated()), id: \.offset) { _, key in
                            Keycap(label: key)
                        }
                    }
                    Text(isHovering ? "click to change" : "to start/stop")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovering || model.isRecordingHotkey ? 0.07 : 0))
            )
            .padding(.horizontal, -6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help("Click to record a new start/stop shortcut. Right-click to reset.")
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

private struct Keycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14))
            )
    }
}
