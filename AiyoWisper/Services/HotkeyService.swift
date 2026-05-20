import Cocoa
import os

/// Tracks the dictation + command-mode modifier hotkeys (Control / Option).
///
/// **Threading contract:** `NSEvent` global-monitor blocks are not guaranteed to be
/// delivered on the main thread. `handleFlagsChanged` runs on whatever thread the
/// system invokes the block on. All access to `isHotkeyPressed` /
/// `isCommandHotkeyPressed` goes through `stateLock` so two near-simultaneous events
/// can't observe inconsistent state. The `on*` closures are `@Sendable` and dispatch
/// to `@MainActor` internally, so it's safe to invoke them from the lock-protected
/// section.
@Observable
final class HotkeyService: @unchecked Sendable {
    /// State is only ever read inside `withStateLock` — do not read directly.
    private var _isHotkeyPressed = false
    private var _isCommandHotkeyPressed = false
    private let stateLock = OSAllocatedUnfairLock()

    @ObservationIgnored
    var onKeyDown: (@Sendable () -> Void)?
    @ObservationIgnored
    var onKeyUp: (@Sendable () -> Void)?

    @ObservationIgnored
    var onCommandKeyDown: (@Sendable () -> Void)?
    @ObservationIgnored
    var onCommandKeyUp: (@Sendable () -> Void)?

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
        print("[Hotkey] Service started — global monitor: \(globalMonitor != nil), local monitor: \(localMonitor != nil)")
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
        stateLock.withLock {
            _isHotkeyPressed = false
            _isCommandHotkeyPressed = false
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        let optionPressed = event.modifierFlags.contains(.option)
        let commandPressed = event.modifierFlags.contains(.command)
        let shiftPressed = event.modifierFlags.contains(.shift)

        // Dictation: Control only (no other modifiers) to start.
        // Compute the desired transition under the lock so concurrent events can't
        // both fire `onKeyDown` on the same press, then invoke the closure outside
        // the lock (closures dispatch to @MainActor and we don't want to hold the
        // lock across that hop).
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
            print("[Hotkey] Control key down detected")
            onKeyDown?()
        case .keyUp:
            print("[Hotkey] Control key up detected (controlPressed: \(controlPressed))")
            onKeyUp?()
        case .none:
            break
        }

        let commandTransition: HotkeyTransition = stateLock.withLock {
            if optionPressed && !controlPressed && !commandPressed && !shiftPressed {
                if !_isCommandHotkeyPressed {
                    _isCommandHotkeyPressed = true
                    return .keyDown
                }
            } else if _isCommandHotkeyPressed {
                _isCommandHotkeyPressed = false
                return .keyUp
            }
            return .none
        }
        switch commandTransition {
        case .keyDown: onCommandKeyDown?()
        case .keyUp: onCommandKeyUp?()
        case .none: break
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
