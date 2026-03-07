import Cocoa
import SwiftUI

@MainActor
final class RecordingOverlay {
    private var panel: NSPanel?
    private var appState: AppState?

    func observe(_ appState: AppState) {
        self.appState = appState
        startObserving()
    }

    private func startObserving() {
        guard let appState else { return }
        withObservationTracking {
            _ = appState.status
            _ = appState.detectedLanguage
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateVisibility()
                self?.startObserving()
            }
        }
    }

    private func updateVisibility() {
        guard let appState else { return }
        switch appState.status {
        case .recording, .transcribing:
            show(status: appState.status)
        default:
            hide()
        }
    }

    private func show(status: DictationStatus) {
        if panel == nil {
            createPanel()
        }

        guard let panel else { return }

        let hostingView = NSHostingView(
            rootView: RecordingOverlayContent(status: status, detectedLanguage: appState?.detectedLanguage)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 44)
        panel.contentView = hostingView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 100
            let y = screenFrame.maxY - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
    }
}

private struct RecordingOverlayContent: View {
    let status: DictationStatus
    var detectedLanguage: String?

    var body: some View {
        HStack(spacing: 8) {
            if status == .recording {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())
                Text("Recording...")
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transcribing...")
                        .font(.caption)
                        .fontWeight(.medium)
                    if let lang = detectedLanguage {
                        Text(lang.uppercased())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
