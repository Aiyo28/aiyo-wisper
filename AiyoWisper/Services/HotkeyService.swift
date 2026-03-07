import Cocoa

@Observable
final class HotkeyService: @unchecked Sendable {
    private(set) var isHotkeyPressed = false

    @ObservationIgnored
    var onKeyDown: (@Sendable () -> Void)?
    @ObservationIgnored
    var onKeyUp: (@Sendable () -> Void)?

    @ObservationIgnored
    private var globalMonitor: Any?
    @ObservationIgnored
    private var localMonitor: Any?

    func start() {
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
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        let otherModifiers: NSEvent.ModifierFlags = [.command, .option, .shift]
        let hasOtherModifiers = !event.modifierFlags.intersection(otherModifiers).isEmpty

        if controlPressed && !isHotkeyPressed && !hasOtherModifiers {
            isHotkeyPressed = true
            onKeyDown?()
        } else if !controlPressed && isHotkeyPressed {
            isHotkeyPressed = false
            onKeyUp?()
        }
    }

    deinit {
        stop()
    }
}
