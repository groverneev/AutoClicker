import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            if !model.isTrusted {
                permissionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            header

            VStack(spacing: 12) {
                intervalCard
                mouseButtonCard
                repeatCard
            }
            .disabled(model.isRunning)
            .opacity(model.isRunning ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 20)
        .frame(width: 460)
        .fixedSize()
        .background {
            LinearGradient(
                colors: [Theme.tint(running: model.isRunning).opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .animation(.smooth(duration: 0.35), value: model.isRunning)
        .animation(.smooth(duration: 0.35), value: model.isTrusted)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                StartStopButton(isRunning: model.isRunning, action: model.toggle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .contentTransition(.opacity)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .fixedSize(horizontal: false, vertical: true)
                    HotkeyRecorderButton(model: model)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(model.clickCount, format: .number)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(model.clickCount)))
                        .animation(.snappy(duration: 0.2), value: model.clickCount)
                        .foregroundStyle(model.clickCount > 0 ? .primary : .tertiary)
                    Text(model.clickCount == 1 ? "click" : "clicks")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            if let limit = clickLimit {
                ProgressView(value: Double(min(model.clickCount, limit)), total: Double(limit))
                    .progressViewStyle(.linear)
                    .tint(Theme.tint(running: model.isRunning))
                    .transition(.opacity)
            }
        }
        .padding(18)
        .card()
    }

    private var statusTitle: String {
        if model.isRunning { return "Clicking" }
        return model.clickCount > 0 ? "Stopped" : "Ready"
    }

    private var summary: String {
        let settings = model.settings
        let interval = switch settings.intervalMode {
        case .fixed:
            "every \(Self.format(milliseconds: settings.fixedIntervalMilliseconds))"
        case .random:
            "every \(settings.randomRangeMilliseconds.lowerBound)–\(settings.randomRangeMilliseconds.upperBound) ms"
        }
        let repeats = switch settings.repeatMode {
        case .untilStopped: "until stopped"
        case .count: settings.job.limit == 1 ? "once" : "\(settings.job.limit ?? 0) times"
        }
        return "\(settings.button.title) click \(interval), \(repeats)."
    }

    /// The progress bar is shown for a counted run, while it runs or after it has clicked.
    private var clickLimit: Int? {
        guard let limit = model.settings.job.limit, model.isRunning || model.clickCount > 0 else { return nil }
        return limit
    }

    private static func format(milliseconds: Int) -> String {
        guard milliseconds >= 1000 else { return "\(milliseconds) ms" }
        return Duration.milliseconds(milliseconds).formatted(
            .units(allowed: [.hours, .minutes, .seconds, .milliseconds], width: .abbreviated)
        )
    }

    // MARK: - Permission

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.orange.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility access needed")
                    .font(.headline)
                Text("Allow Auto Clicker to click in other apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { model.openAccessibilitySettings() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(.orange.opacity(0.3)))
    }

    // MARK: - Settings cards

    private var intervalCard: some View {
        SettingsCard(title: "Interval", systemImage: "timer") {
            PillPicker(
                selection: $model.settings.intervalMode,
                options: [(.fixed, "Fixed"), (.random, "Random")]
            )
        } content: {
            switch model.settings.intervalMode {
            case .fixed:
                HStack(spacing: 8) {
                    UnitField(value: $model.settings.hours, unit: "hours")
                    UnitField(value: $model.settings.minutes, unit: "minutes")
                    UnitField(value: $model.settings.seconds, unit: "seconds")
                    UnitField(value: $model.settings.milliseconds, unit: "milliseconds")
                }
            case .random:
                HStack(spacing: 12) {
                    UnitField(value: $model.settings.randomMin, unit: "min · ms")
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    UnitField(value: $model.settings.randomMax, unit: "max · ms")
                }
            }
        }
    }

    private var mouseButtonCard: some View {
        SettingsCard(title: "Mouse button", systemImage: "computermouse") {
            EmptyView()
        } content: {
            HStack(spacing: 8) {
                ForEach([MouseButton.left, .middle, .right]) { button in
                    MouseButtonTile(
                        button: button,
                        isSelected: model.settings.button == button
                    ) {
                        model.settings.button = button
                    }
                }
            }
        }
    }

    private var repeatCard: some View {
        SettingsCard(title: "Repeat", systemImage: "repeat") {
            PillPicker(
                selection: $model.settings.repeatMode,
                options: [(.untilStopped, "Forever"), (.count, "Count")]
            )
        } content: {
            switch model.settings.repeatMode {
            case .untilStopped:
                HStack(spacing: 10) {
                    Image(systemName: "infinity")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.tint(running: false))
                    Text("Keeps clicking until you press Stop or the hotkey.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: UnitField.height)
            case .count:
                HStack(spacing: 10) {
                    UnitField(value: $model.settings.repeatCount, unit: "clicks", minimum: 1)
                        .frame(width: 120)
                    Stepper("Clicks", value: $model.settings.repeatCount, in: 1...1_000_000)
                        .labelsHidden()
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Theme

private enum Theme {
    static let cornerRadius: CGFloat = 14

    static let startColors = [Color(red: 0.33, green: 0.49, blue: 1.0), Color(red: 0.55, green: 0.33, blue: 0.98)]
    static let stopColors = [Color(red: 1.0, green: 0.45, blue: 0.33), Color(red: 0.93, green: 0.2, blue: 0.42)]

    static func tint(running: Bool) -> Color {
        running ? stopColors[1] : startColors[0]
    }
}

private extension View {
    /// The rounded, softly outlined surface every section sits on.
    func card() -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

// MARK: - Components

private struct SettingsCard<Accessory: View, Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .labelStyle(CardTitleLabelStyle())
                Spacer()
                accessory
            }
            content
        }
        .padding(14)
        .card()
    }
}

private struct CardTitleLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tint(running: false))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.tint(running: false).opacity(0.14)))
            configuration.title
        }
    }
}

/// The big round Start/Stop button, with a pulse while clicking.
private struct StartStopButton: View {
    let isRunning: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 84

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRunning && !reduceMotion {
                    PulseRings(color: Theme.stopColors[1], size: size)
                }
                Circle()
                    .fill(LinearGradient(
                        colors: isRunning ? Theme.stopColors : Theme.startColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Theme.tint(running: isRunning).opacity(0.45), radius: isHovering ? 14 : 9, y: 5)
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: isRunning ? 0 : 3) // Optically center the play triangle.
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .scaleEffect(isHovering ? 1.04 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.spring(duration: 0.3), value: isHovering)
        .help(isRunning ? "Stop clicking" : "Start clicking")
        .accessibilityLabel(isRunning ? "Stop" : "Start")
    }
}

private struct PulseRings: View {
    let color: Color
    let size: CGFloat
    private let period = 1.6

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2) { index in
                    let phase = ((time / period) + Double(index) / 2).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(1 + 0.4 * phase)
                        .opacity(0.5 * (1 - phase))
                }
            }
            .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// A segmented control with a sliding accent-colored pill.
private struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                let isSelected = value == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = value }
                } label: {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(LinearGradient(colors: Theme.startColors, startPoint: .leading, endPoint: .trailing))
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

/// A large, centered number box with its unit underneath.
private struct UnitField: View {
    static let height: CGFloat = 58

    @Binding var value: Int
    let unit: String
    var minimum = 0

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 1) {
            TextField(unit, value: clamped, format: .number.grouping(.never))
                .textFieldStyle(.plain)
                .labelsHidden()
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .focusEffectDisabled()
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused ? Theme.tint(running: false) : Color.primary.opacity(0.1),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var clamped: Binding<Int> {
        Binding(get: { value }, set: { value = max(minimum, $0) })
    }
}

/// A selectable tile showing a mouse with the chosen button highlighted.
private struct MouseButtonTile: View {
    let button: MouseButton
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MouseGlyph(button: button, highlight: isSelected ? Theme.tint(running: false) : Color.primary.opacity(0.2))
                Text(button.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.tint(running: false).opacity(0.12) : Color.primary.opacity(isHovering ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Theme.tint(running: false) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MouseGlyph: View {
    let button: MouseButton
    let highlight: Color

    private let width: CGFloat = 24
    private let height: CGFloat = 36
    private var splitY: CGFloat { height * 0.42 }

    var body: some View {
        let body = RoundedRectangle(cornerRadius: width / 2, style: .continuous)
        ZStack(alignment: .top) {
            // Highlighted button half.
            if button != .middle {
                HStack(spacing: 0) {
                    Rectangle().fill(button == .left ? highlight : .clear)
                    Rectangle().fill(button == .right ? highlight : .clear)
                }
                .frame(height: splitY)
            }
            // Dividers between the buttons and the body.
            Rectangle()
                .fill(.secondary)
                .frame(width: 1.5, height: splitY)
            Rectangle()
                .fill(.secondary)
                .frame(height: 1.5)
                .offset(y: splitY)
            // Scroll wheel.
            Capsule()
                .fill(button == .middle ? highlight : Color(nsColor: .controlBackgroundColor))
                .overlay(Capsule().strokeBorder(.secondary, lineWidth: 1.2))
                .frame(width: 5, height: 9)
                .offset(y: 4)
        }
        .frame(width: width, height: height, alignment: .top)
        .clipShape(body)
        .overlay(body.strokeBorder(.secondary, lineWidth: 1.5))
    }
}
