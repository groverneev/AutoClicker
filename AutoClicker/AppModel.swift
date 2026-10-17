import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var settings = ClickSettings.load() {
        didSet { settings.save() }
    }

    var hotkey = Hotkey.load() {
        didSet {
            hotkey.save()
            registerHotkey()
        }
    }

    /// While recording a new shortcut the old one is unregistered, so pressing it gets captured
    /// by the recorder instead of toggling the clicker.
    var isRecordingHotkey = false {
        didSet { registerHotkey() }
    }

    private(set) var isRunning = false
    private(set) var clickCount = 0
    private(set) var isTrusted = AccessibilityPermission.isTrusted

    @ObservationIgnored private let exclusionZone = ExclusionZone()
    @ObservationIgnored private var session: ClickSession?
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var windowObservers: [NSObjectProtocol] = []

    init() {
        HotkeyCenter.shared.onPress = { [weak self] in self?.toggle() }
        registerHotkey()
        watchAccessibilityPermission()
    }

    // MARK: - Start / stop

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning else { return }

        isTrusted = AccessibilityPermission.isTrusted
        guard isTrusted else {
            AccessibilityPermission.requestAccess()
            return
        }

        // Commit any number the user is still typing so it's included in the job.
        window?.makeFirstResponder(nil)

        // Callbacks from a previous session can still arrive after a quick stop/start, so each
        // session is tagged and stale callbacks are ignored.
        let sessionID = UUID()
        let session = ClickSession(
            job: settings.job,
            exclusionZone: exclusionZone,
            onProgress: { [weak self] count in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.sessionProgressed(sessionID, count: count) }
                }
            },
            onFinish: { [weak self] count in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.sessionFinished(sessionID, count: count) }
                }
            }
        )
        self.session = session
        self.sessionID = sessionID
        clickCount = 0
        isRunning = true

        // Keep App Nap from throttling the click thread while the app is in the background.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical, .idleDisplaySleepDisabled],
            reason: "Auto clicking"
        )

        session.start()
    }

    func stop() {
        session?.stop()
        // Keep the click count from the session that just ended, but stop listening to it.
        cleanUpAfterSession()
    }

    private func sessionProgressed(_ id: UUID, count: Int) {
        guard id == sessionID else { return }
        clickCount = count
    }

    private func sessionFinished(_ id: UUID, count: Int) {
        guard id == sessionID else { return }
        clickCount = count
        cleanUpAfterSession()
    }

    private func cleanUpAfterSession() {
        session = nil
        sessionID = nil
        isRunning = false
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        HotkeyCenter.shared.register(isRecordingHotkey ? nil : hotkey)
    }

    func resetHotkey() {
        hotkey = .defaultShortcut
    }

    // MARK: - Accessibility

    func openAccessibilitySettings() {
        AccessibilityPermission.requestAccess()
        AccessibilityPermission.openSettings()
    }

    private func watchAccessibilityPermission() {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let trusted = AccessibilityPermission.isTrusted
                if trusted != self.isTrusted {
                    self.isTrusted = trusted
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Window tracking

    /// Tracks the main window so clicks landing on it are suppressed.
    func attach(window: NSWindow) {
        guard window !== self.window else { return }
        self.window = window
        windowObservers.forEach(NotificationCenter.default.removeObserver)

        let names: [Notification.Name] = [
            NSWindow.didMoveNotification, NSWindow.didResizeNotification,
            NSWindow.didChangeScreenNotification, NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification,
            NSWindow.didChangeOcclusionStateNotification,
        ]
        windowObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateExclusionZone() }
            }
        }
        windowObservers += [NSApplication.didHideNotification, NSApplication.didUnhideNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateExclusionZone() }
            }
        }
        updateExclusionZone()
    }

    private func updateExclusionZone() {
        guard let window, window.isVisible, !window.isMiniaturized, !NSApp.isHidden,
              let primaryScreen = NSScreen.screens.first
        else {
            exclusionZone.rect = nil
            return
        }
        // Convert from Cocoa (bottom-left origin) to CoreGraphics (top-left origin) coordinates.
        let frame = window.frame
        exclusionZone.rect = CGRect(
            x: frame.minX,
            y: primaryScreen.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}
