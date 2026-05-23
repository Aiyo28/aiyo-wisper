import Cocoa
import os

/// Tracks the dictation modifier hotkey (Control).
///
/// **Threading contract:** `NSEvent` global-monitor blocks are not guaranteed to be
/// delivered on the main thread. `handleFlagsChanged` runs on whatever thread the
/// system invokes the block on. All access to `_isHotkeyPressed` goes through
/// `stateLock` so two near-simultaneous events can't observe inconsistent state.
/// The `on*` closures are `@Sendable` and dispatch to `@MainActor` internally, so
/// it's safe to invoke them from the lock-protected section.
@Observable
final class HotkeyService: @unchecked Sendable {
    private var _isHotkeyPressed = false
    private let stateLock = OSAllocatedUnfairLock()

    @ObservationIgnored
    var onKeyDown: (@Sendable () -> Void)?
    @ObservationIgnored
    var onKeyUp: (@Sendable () -> Void)?

    @ObservationIgnored
    private var globalMonitor: Any?
    @ObservationIgnored
    private var localMonitor: Any?

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        Log.hotkey.info("Service started — global monitor: \(self.globalMonitor != nil), local monitor: \(self.localMonitor != nil)")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        stateLock.withLock { _isHotkeyPressed = false }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        let optionPressed = event.modifierFlags.contains(.option)
        let commandPressed = event.modifierFlags.contains(.command)
        let shiftPressed = event.modifierFlags.contains(.shift)

        // Dictation: Control only (no other modifiers).
        let dictationTransition: HotkeyTransition = stateLock.withLock {
            if controlPressed && !optionPressed && !commandPressed && !shiftPressed {
                if !_isHotkeyPressed {
                    _isHotkeyPressed = true
                    return .keyDown
                }
            } else if _isHotkeyPressed {
                _isHotkeyPressed = false
                return .keyUp
            }
            return .none
        }
        switch dictationTransition {
        case .keyDown:
            Log.hotkey.info("Control key down detected")
            onKeyDown?()
        case .keyUp:
            Log.hotkey.info("Control key up detected (controlPressed: \(controlPressed))")
            onKeyUp?()
        case .none:
            break
        }
    }

    private enum HotkeyTransition {
        case keyDown, keyUp, none
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
