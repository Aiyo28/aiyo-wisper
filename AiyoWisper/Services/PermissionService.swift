import AVFAudio
import Cocoa
import Foundation

@MainActor @Observable
final class PermissionService {
    var hasMicrophoneAccess = false
    var hasAccessibilityAccess = false
    var microphoneWasDenied = false

    func refreshPermissions() {
        let micPermission = AVAudioApplication.shared.recordPermission
        hasMicrophoneAccess = micPermission == .granted
        microphoneWasDenied = micPermission == .denied
        hasAccessibilityAccess = AXIsProcessTrusted()
    }

    func requestMicrophonePermission() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        hasMicrophoneAccess = granted
        microphoneWasDenied = !granted && AVAudioApplication.shared.recordPermission == .denied
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        Self.openAccessibilitySettings()
    }

    // MARK: - Static convenience for pipeline use (nonisolated for cross-actor access)

    nonisolated static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    nonisolated static func checkMicrophonePermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    nonisolated static func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Checks accessibility and shows the system prompt dialog if not granted.
    nonisolated static func promptAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
