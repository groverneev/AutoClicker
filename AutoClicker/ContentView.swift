import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.isTrusted {
                permissionBanner
                Divider()
            }

            intervalSection
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .disabled(model.isRunning)

            Divider()

            HStack(spacing: 0) {
                mouseButtonSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                Divider()
                repeatSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
            .frame(height: 88)
            .disabled(model.isRunning)

            Divider()

            controlSection
                .padding(14)
                .frame(height: 124)
        }
        .frame(width: 600)
        .fixedSize()
    }

    // MARK: - Sections

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Auto Clicker needs Accessibility access to click.")
            Spacer()
            Button("Open Settings…") { model.openAccessibilitySettings() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.yellow.opacity(0.12))
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Click interval", isOn: intervalModeBinding(.fixed))

            HStack(spacing: 8) {
                NumberField(value: $model.settings.hours, width: 60)
                Text("hours")
                NumberField(value: $model.settings.minutes, width: 60)
                Text("minutes")
                NumberField(value: $model.settings.seconds, width: 60)
                Text("seconds")
                NumberField(value: $model.settings.milliseconds, width: 60)
                Text("milliseconds")
            }
            .lineLimit(1)
            .disabled(model.settings.intervalMode != .fixed)

            Toggle("Interval random range", isOn: intervalModeBinding(.random))
                .padding(.top, 4)

            HStack(spacing: 8) {
                Text("Min:")
                NumberField(value: $model.settings.randomMin)
                Text("milliseconds")
                Spacer()
                Text("Max:")
                NumberField(value: $model.settings.randomMax)
                Text("milliseconds")
                Spacer()
            }
            .disabled(model.settings.intervalMode != .random)
        }
        .toggleStyle(.checkbox)
    }

    private var mouseButtonSection: some View {
        HStack(spacing: 12) {
            Text("Mouse button:")
            Picker("Mouse button", selection: $model.settings.button) {
                ForEach(MouseButton.allCases) { button in
                    Text(button.title).tag(button)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Toggle("Repeat", isOn: repeatModeBinding(.count))
                NumberField(value: $model.settings.repeatCount)
                    .disabled(model.settings.repeatMode != .count)
                Text("times")
            }
            Toggle("Repeat until stopped", isOn: repeatModeBinding(.untilStopped))
        }
        .toggleStyle(.checkbox)
    }

    private var controlSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
            GridRow {
                Text(model.statusText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(model.isRunning ? .primary : .secondary)
                    .frame(width: 140, alignment: .leading)
                Button {
                    model.toggle()
                } label: {
                    Text(model.isRunning ? "Stop" : "Start")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .frame(width: 200)
            }
            GridRow {
                Text("Start/Stop hotkey:")
                HotkeyRecorderButton(model: model)
                    .frame(width: 200)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Bindings

    /// The two interval checkboxes behave like radio buttons: checking one unchecks the other.
    private func intervalModeBinding(_ mode: ClickSettings.IntervalMode) -> Binding<Bool> {
        Binding(
            get: { model.settings.intervalMode == mode },
            set: { if $0 { model.settings.intervalMode = mode } }
        )
    }

    private func repeatModeBinding(_ mode: ClickSettings.RepeatMode) -> Binding<Bool> {
        Binding(
            get: { model.settings.repeatMode == mode },
            set: { if $0 { model.settings.repeatMode = mode } }
        )
    }
}

/// A compact non-negative integer field.
private struct NumberField: View {
    @Binding var value: Int
    var width: CGFloat = 80

    var body: some View {
        TextField("", value: clamped, format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
    }

    private var clamped: Binding<Int> {
        Binding(get: { value }, set: { value = max(0, $0) })
    }
}
