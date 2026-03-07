import Carbon.HIToolbox
import Cocoa

struct TextInjector {
    static func inject(_ text: String) {
        guard PermissionService.checkAccessibilityPermission() else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""

        if Constants.TextInjection.terminalBundleIDs.contains(bundleID) {
            injectViaClipboard(text)
        } else {
            injectViaKeyboard(text)
        }
    }

    // MARK: - CGEvent keyboard simulation

    private static func injectViaKeyboard(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Process text in chunks that fit CGEvent's unicode string limit (20 chars)
        let chunkSize = 20
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = Array(text[index..<end].utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
            keyUp?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)

            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)

            usleep(Constants.TextInjection.interCharacterDelay)
            index = end
        }
    }

    // MARK: - Clipboard fallback for terminals

    private static func injectViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
