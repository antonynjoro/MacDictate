import Foundation
import Cocoa
import CoreGraphics

// MARK: - Key Codes

// MARK: - Key Monitor

/// Monitors global keyboard events using a CGEvent tap.
/// Replaces Python's polling-based `KeyMonitor` with an interrupt-driven approach.
///
/// ## Architecture Difference
/// The Python version polled `CGEventSourceKeyState` every 50ms in a busy loop,
/// consuming 2–5% CPU at idle. This implementation uses `CGEvent.tapCreate()` —
/// an OS-level callback that fires only when a relevant key event occurs.
/// Idle CPU usage: <0.1%.
final class KeyMonitor {

    // MARK: Dependencies

    private let stateMachine: AppStateMachine
    private let onStartRecording: () -> Void
    /// Requests that recording end and processing begin.
    private let onStopRecording: () -> Void
    /// Fired when the global Polish shortcut chord is pressed (any time).
    var onPolishShortcut: (() -> Void)?

    // MARK: State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Whether the tap is currently installed. Guards against a double `start()`
    /// (e.g. the post-grant retry) leaking a second tap + a duplicate
    /// trigger-key observer.
    private(set) var isRunning = false
    /// Throttles the tap-creation failure log to once per failing streak, so
    /// repeated retries while Accessibility is missing don't flood the log.
    private var didLogTapFailure = false
    private var triggerKey: TriggerKey = Config.triggerKey
    private var isTriggerKeyPressed = false
    private var recordingStartTime: Date?

    /// Safety timeout to prevent stuck recording state (2 minutes).
    private let maxRecordingDuration: TimeInterval = 120.0
    private var timeoutTimer: Timer?

    /// Watchdog that polls the physical trigger-key state while recording.
    /// Some keys — notably Fn/Globe when macOS maps it to a system action like
    /// "Show Emoji & Symbols" — get their key-up event swallowed by the OS before
    /// it reaches our listen-only tap. Without this, a swallowed release strands
    /// the mic on (no `flagsChanged` ever clears `isTriggerKeyPressed`). The
    /// watchdog detects the key is no longer physically down and forces release.
    /// Active only between press and release, so idle CPU is unaffected.
    private var releaseWatchdog: Timer?
    private let releaseWatchdogInterval: TimeInterval = 0.12

    // MARK: Lifecycle

    init(
        stateMachine: AppStateMachine,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void
    ) {
        self.stateMachine = stateMachine
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
    }

    deinit {
        stop()
    }

    // MARK: - Start / Stop

    /// Install a CGEvent tap to monitor modifier key changes globally.
    /// Requires Accessibility trust (a trusted process may create listen-only
    /// taps). Returns whether the tap was created — note tapCreate can succeed
    /// while events are withheld pending trust, so success is NOT a permission
    /// check; gate on AXIsProcessTrusted instead. Idempotent: a second call while
    /// already running is a no-op that reports the existing success.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        // Event mask: flagsChanged (modifier keys) + keyDown (to detect Q)
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        // Store `self` as an Unmanaged pointer to pass into the C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    // Re-enable the tap if the system disabled it
                    if let userInfo = userInfo {
                        let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                        if let tap = monitor.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                            Log.debug("KeyMonitor", "Event tap re-enabled after system timeout")
                        }
                    }
                    return Unmanaged.passRetained(event)
                }

                if let userInfo = userInfo {
                    let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                    monitor.handleEvent(event)
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: refcon
        ) else {
            guard !didLogTapFailure else { return false }
            didLogTapFailure = true
            let processName = ProcessInfo.processInfo.processName
            let parentApp = Bundle.main.bundleIdentifier ?? "this app"
            Log.error("KeyMonitor", """
            ⚠️ Failed to create event tap!

            To fix this, grant Accessibility permission:
              1. Open System Settings → Privacy & Security → Accessibility
              2. Turn on the toggle for ZeroG (or the app that launched it,
                 e.g. Terminal.app or Xcode.app when running unbundled)
              3. Restart ZeroG

            Process: \(processName) | Bundle: \(parentApp)
            """)
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerKeyChanged(_:)),
            name: .triggerKeyDidChange,
            object: nil
        )

        isRunning = true
        didLogTapFailure = false
        Log.debug("KeyMonitor", "Event tap installed. Monitoring \(triggerKey.displayName) key.")
        return true
    }

    /// Remove the event tap and clean up.
    func stop() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        stopReleaseWatchdog()

        NotificationCenter.default.removeObserver(self)

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false

        Log.debug("KeyMonitor", "Event tap removed.")
    }

    // MARK: - Trigger Key Change

    @objc private func triggerKeyChanged(_ notification: Notification) {
        guard let newKey = notification.userInfo?[Config.NotificationKeys.triggerKey] as? TriggerKey else { return }

        let wasRecording = isTriggerKeyPressed
        triggerKey = newKey

        if wasRecording {
            isTriggerKeyPressed = false
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            stopReleaseWatchdog()
            DispatchQueue.main.async { [weak self] in
                self?.onStopRecording()
            }
        }

        Log.debug("KeyMonitor", "Trigger key changed to \(newKey.displayName)")
    }

    // MARK: - Event Handling

    /// Process a raw CGEvent from the tap callback.
    private func handleEvent(_ event: CGEvent) {
        let type = event.type

        // Handle modifier key changes (trigger key press/release)
        if type == .flagsChanged {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            guard keyCode == Int64(triggerKey.keyCode) else { return }

            let isTriggerFlagSet = flags.rawValue & triggerKey.deviceFlagMask != 0

            if isTriggerFlagSet && !isTriggerKeyPressed {
                triggerPressed()
            } else if !isTriggerFlagSet && isTriggerKeyPressed {
                triggerReleased()
            }
        }

        // Global Polish shortcut: a keyDown whose keyCode + modifiers match the
        // configured chord exactly (ignore auto-repeat so it fires once per press).
        if type == .keyDown,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           matchesPolishShortcut(event) {
            DispatchQueue.main.async { [weak self] in self?.onPolishShortcut?() }
        }
    }

    /// Exact match against `Config.polishShortcut`: the keyCode and the four
    /// modifier masks must all agree (no extra modifiers held).
    private func matchesPolishShortcut(_ event: CGEvent) -> Bool {
        let shortcut = Config.polishShortcut
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(shortcut.keyCode) else { return false }
        let flags = event.flags
        let pairs: [(Config.PolishModifiers, CGEventFlags)] = [
            (.control, .maskControl), (.option, .maskAlternate),
            (.shift, .maskShift),     (.command, .maskCommand),
        ]
        for (mod, cg) in pairs where shortcut.modifiers.contains(mod) != flags.contains(cg) {
            return false
        }
        return true
    }

    // MARK: - Trigger Key Actions

    private func triggerPressed() {
        isTriggerKeyPressed = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let state = self.stateMachine.currentState

            guard state.isReady else {
                Log.info("KeyMonitor", "Press ignored — app busy (state: \(state))")
                // The user's speech after this press is NOT being recorded —
                // whether we're still loading the model (~45s after launch) or
                // mid-transcription. Make that audible instead of silently
                // eating it.
                NSSound(named: "Basso")?.play()
                return
            }

            switch state {
            case .idle, .success, .error, .needsPermission:
                self.recordingStartTime = Date()
                Log.info("KeyMonitor", "Press → recording (\(self.triggerKey.displayName))")
                self.stateMachine.transition(to: .recording)
                self.onStartRecording()
                self.startTimeoutTimer()
                self.startReleaseWatchdog()
            default:
                break
            }
        }
    }

    private func triggerReleased() {
        isTriggerKeyPressed = false
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        stopReleaseWatchdog()

        let held = recordingStartTime.map { String(format: "%.1fs", Date().timeIntervalSince($0)) } ?? "?"
        Log.info("KeyMonitor", "Release → stop recording (held \(held))")

        DispatchQueue.main.async { [weak self] in
            self?.onStopRecording()
        }

        recordingStartTime = nil
    }

    // MARK: - Safety Timeout

    private func startTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            guard let self else { return }

            Log.info("KeyMonitor", "Recording timeout (\(self.maxRecordingDuration)s) — forcing stop.")

            self.isTriggerKeyPressed = false
            self.stopReleaseWatchdog()
            self.onStopRecording()
        }
    }

    // MARK: - Release Watchdog

    /// Begin polling the physical trigger-key state. Catches a swallowed key-up
    /// (e.g. OS-intercepted Fn/Globe) that would otherwise leave the mic stuck on.
    private func startReleaseWatchdog() {
        releaseWatchdog?.invalidate()
        releaseWatchdog = Timer.scheduledTimer(withTimeInterval: releaseWatchdogInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isTriggerKeyPressed else {
                self.stopReleaseWatchdog()
                return
            }
            // Live session modifier flags — same domain as the flagsChanged
            // events we consume. Per-keycode keyState is unreliable for held
            // modifiers (Right Shift reads "up" mid-hold → false stop).
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let stillDown = flags.contains(self.triggerKey.familyFlagMask)
            if !stillDown {
                Log.info("KeyMonitor", "Watchdog: \(self.triggerKey.displayName) release was missed — forcing stop.")
                self.triggerReleased()
            }
        }
    }

    private func stopReleaseWatchdog() {
        releaseWatchdog?.invalidate()
        releaseWatchdog = nil
    }
}
