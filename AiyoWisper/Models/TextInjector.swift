import Carbon.HIToolbox
import Cocoa

/// All public methods are `async` because they can take 100-1000ms (clipboard wait,
/// per-character delays). The previous sync API used `usleep`, which stalled the run
/// loop on @MainActor call paths and dropped pending keyboard events.
struct TextInjector {
    @discardableResult
    static func inject(_ text: String, charByChar: Bool = false) async -> Bool {
        guard PermissionService.checkAccessibilityPermission() else { return false }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""

        if Constants.TextInjection.terminalBundleIDs.contains(bundleID) {
            await injectViaClipboard(text)
        } else if charByChar {
            await injectViaKeyboardCharByChar(text)
        } else {
            await injectViaKeyboard(text)
        }
        return true
    }

    // MARK: - Read & Replace Selection

    /// Reads the currently selected text by simulating Cmd+C and reading the clipboard.
    /// Returns nil if no text is selected.
    static func readSelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()

        simulateKeyCombination(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        // Async sleep — does NOT block the main run loop.
        try? await Task.sleep(for: .milliseconds(200))

        let selection = pasteboard.string(forType: .string)

        // Restore previous clipboard contents
        pasteboard.clearContents()
        if let previous = previousContents {
            pasteboard.setString(previous, forType: .string)
        }

        guard let result = selection, !result.isEmpty else { return nil }
        return result
    }

    /// Replaces the currently selected text by pasting the given text via Cmd+V.
    static func replaceSelection(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateKeyCombination(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        // Restore clipboard after a short delay, but only if the user hasn't modified it
        let changeCountAfterPaste = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pasteboard.changeCount == changeCountAfterPaste else { return }
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    // MARK: - Key simulation helpers

    /// Simulates a key combination (key-down + key-up) with the given modifier flags.
    private static func simulateKeyCombination(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - CGEvent keyboard simulation

    private static func injectViaKeyboard(_ text: String) async {
        let source = CGEventSource(stateID: .hidSystemState)
        let chunkDelay = Constants.TextInjection.interCharacterDelay

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

            try? await Task.sleep(for: .microseconds(Int(chunkDelay)))
            index = end
        }
    }

    // MARK: - Character-by-character keyboard simulation (Raycast/text expander compatible)

    private static func injectViaKeyboardCharByChar(_ text: String) async {
        let source = CGEventSource(stateID: .hidSystemState)
        let charDelay = Constants.TextInjection.interCharacterDelay

        for char in text {
            let utf16 = Array(String(char).utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)

            try? await Task.sleep(for: .microseconds(Int(charDelay)))
        }
    }

    // MARK: - Clipboard fallback for terminals

    private static func injectViaClipboard(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateKeyCombination(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        // Restore clipboard after a short delay, but only if the user hasn't modified it
        let changeCountAfterPaste = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pasteboard.changeCount == changeCountAfterPaste else { return }
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
