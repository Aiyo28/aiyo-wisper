import Cocoa

@Observable
final class HotkeyService: @unchecked Sendable {
    private(set) var isHotkeyPressed = false
    private(set) var isCommandHotkeyPressed = false

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
        isHotkeyPressed = false
        isCommandHotkeyPressed = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        let optionPressed = event.modifierFlags.contains(.option)
        let commandPressed = event.modifierFlags.contains(.command)
        let shiftPressed = event.modifierFlags.contains(.shift)

        // Dictation: Control only (no other modifiers)
        if controlPressed && !optionPressed && !commandPressed && !shiftPressed {
            if !isHotkeyPressed {
                isHotkeyPressed = true
                onKeyDown?()
            }
        } else if !controlPressed && isHotkeyPressed {
            isHotkeyPressed = false
            onKeyUp?()
        }

        // Command mode: Option only (no other modifiers)
        if optionPressed && !controlPressed && !commandPressed && !shiftPressed {
            if !isCommandHotkeyPressed {
                isCommandHotkeyPressed = true
                onCommandKeyDown?()
            }
        } else if !optionPressed && isCommandHotkeyPressed {
            isCommandHotkeyPressed = false
            onCommandKeyUp?()
        }
    }

    deinit {
        stop()
    }
}
