import CoreGraphics
import Foundation

enum MouseButton: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right
    case middle

    var id: Self { self }

    var title: String { rawValue.capitalized }

    fileprivate var cgButton: CGMouseButton {
        switch self {
        case .left: .left
        case .right: .right
        case .middle: .center
        }
    }

    fileprivate var downType: CGEventType {
        switch self {
        case .left: .leftMouseDown
        case .right: .rightMouseDown
        case .middle: .otherMouseDown
        }
    }

    fileprivate var upType: CGEventType {
        switch self {
        case .left: .leftMouseUp
        case .right: .rightMouseUp
        case .middle: .otherMouseUp
        }
    }
}

/// An immutable snapshot of what to click and how often.
struct ClickJob: Sendable {
    enum Interval: Sendable {
        case fixed(milliseconds: Int)
        case random(milliseconds: ClosedRange<Int>)

        var nextDelayNanoseconds: UInt64 {
            let ms = switch self {
            case .fixed(let ms): ms
            case .random(let range): Int.random(in: range)
            }
            return UInt64(max(1, ms)) * 1_000_000
        }
    }

    var interval: Interval
    var button: MouseButton
    /// `nil` means click until stopped.
    var limit: Int?
}

/// Screen area (in global CoreGraphics coordinates) where clicks are suppressed — the app's own
/// window, so the clicker never clicks its own Stop button. Shared between the main thread and
/// the click thread.
final class ExclusionZone: @unchecked Sendable {
    private let lock = NSLock()
    private var _rect: CGRect?

    var rect: CGRect? {
        get { lock.withLock { _rect } }
        set { lock.withLock { _rect = newValue } }
    }
}

/// One run of the auto clicker on a dedicated high-priority thread. Create a new session for
/// every start; a stopped session can't be restarted.
final class ClickSession: @unchecked Sendable {
    private let job: ClickJob
    private let exclusionZone: ExclusionZone
    private let stopSignal = DispatchSemaphore(value: 0)
    private let onProgress: @Sendable (Int) -> Void
    private let onFinish: @Sendable (Int) -> Void

    /// Minimum time between progress callbacks so fast intervals don't flood the main thread.
    private static let progressThrottle: UInt64 = 50_000_000

    init(
        job: ClickJob,
        exclusionZone: ExclusionZone,
        onProgress: @escaping @Sendable (Int) -> Void,
        onFinish: @escaping @Sendable (Int) -> Void
    ) {
        self.job = job
        self.exclusionZone = exclusionZone
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func start() {
        let thread = Thread { [self] in run() }
        thread.name = "AutoClicker.ClickSession"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func stop() {
        stopSignal.signal()
    }

    private func run() {
        let source = CGEventSource(stateID: .hidSystemState)
        var count = 0
        var lastReport: UInt64 = 0
        var deadline = DispatchTime.now().uptimeNanoseconds

        while true {
            if click(source: source) {
                count += 1
            }

            let now = DispatchTime.now().uptimeNanoseconds
            if now - lastReport >= Self.progressThrottle {
                lastReport = now
                onProgress(count)
            }

            if let limit = job.limit, count >= limit { break }

            // Schedule against the previous deadline so the average rate doesn't drift, but don't
            // try to "catch up" with a burst if we fell behind.
            deadline = max(deadline + job.interval.nextDelayNanoseconds, now)
            if stopSignal.wait(timeout: DispatchTime(uptimeNanoseconds: deadline)) == .success {
                break
            }
        }

        onFinish(count)
    }

    /// Posts a down/up pair at the current cursor position. Returns `false` if the click was
    /// suppressed because the cursor is over the app's own window.
    private func click(source: CGEventSource?) -> Bool {
        guard let location = CGEvent(source: nil)?.location else { return false }
        if let zone = exclusionZone.rect, zone.contains(location) { return false }

        let button = job.button
        guard
            let down = CGEvent(mouseEventSource: source, mouseType: button.downType,
                               mouseCursorPosition: location, mouseButton: button.cgButton),
            let up = CGEvent(mouseEventSource: source, mouseType: button.upType,
                             mouseCursorPosition: location, mouseButton: button.cgButton)
        else { return false }

        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
