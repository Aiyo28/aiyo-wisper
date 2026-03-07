import AVFoundation
import Cocoa
import Foundation

@MainActor @Observable
final class PermissionService {
    var hasMicrophoneAccess = false
    var hasAccessibilityAccess = false

    func refreshPermissions() {
        hasMicrophoneAccess = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        hasAccessibilityAccess = AXIsProcessTrusted()
    }

    func requestMicrophonePermission() async {
        hasMicrophoneAccess = await AVCaptureDevice.requestAccess(for: .audio)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Static convenience for pipeline use (nonisolated for cross-actor access)

    nonisolated static func checkMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    nonisolated static func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }
}
