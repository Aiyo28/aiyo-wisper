import Cocoa
import SwiftUI

@MainActor
final class RecordingOverlay {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingOverlayContent>?
    private var appState: AppState?
    private var isVisible = false

    func observe(_ appState: AppState) {
        self.appState = appState
        startObserving()
    }

    private func startObserving() {
        guard let appState else { return }
        withObservationTracking {
            _ = appState.status
            _ = appState.lastCommand
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
        case .recording, .transcribing,
             .commandRecording, .commandTranscribing, .commandProcessing:
            show(status: appState.status)
        default:
            hide()
        }
    }

    private func show(status: DictationStatus) {
        if panel == nil {
            createPanel()
        }

        guard let panel, let hostingView else { return }

        hostingView.rootView = RecordingOverlayContent(status: status)

        if !isVisible {
            isVisible = true

            guard let screen = NSScreen.main else { return }
            let pillWidth: CGFloat = 120
            let pillHeight: CGFloat = 44
            let x = screen.frame.midX - pillWidth / 2
            let targetY = screen.frame.minY + 80

            panel.setFrame(NSRect(x: x, y: targetY - 20, width: pillWidth, height: pillHeight), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(NSPoint(x: x, y: targetY))
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hide() {
        guard isVisible, let panel else { return }
        isVisible = false

        let currentOrigin = panel.frame.origin

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: currentOrigin.x, y: currentOrigin.y - 20))
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.hostingView?.rootView = RecordingOverlayContent(status: .idle)
        })
    }

    private func createPanel() {
        let pillWidth: CGFloat = 120
        let pillHeight: CGFloat = 44

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = RecordingOverlayContent(status: .idle)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight)
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting
    }
}

// MARK: - SwiftUI Content

private struct RecordingOverlayContent: View {
    let status: DictationStatus

    private var isCommandMode: Bool {
        switch status {
        case .commandRecording, .commandTranscribing, .commandProcessing:
            true
        default:
            false
        }
    }

    private var isRecording: Bool {
        status == .recording || status == .commandRecording
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color.black.opacity(0.85))
            .frame(width: 120, height: 44)
            .overlay {
                WaveformView(isRecording: isRecording, isCommandMode: isCommandMode)
            }
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let isRecording: Bool
    let isCommandMode: Bool

    private let barCount = 9
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3
    private let maxBarHeight: CGFloat = 20
    private let minBarHeight: CGFloat = 4

    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 9)
    @State private var animationTimer: Timer?

    private var barColor: Color {
        isCommandMode ? Color(red: 0.7, green: 0.5, blue: 1.0) : .white
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
        .onAppear {
            if isRecording {
                startAnimating()
            } else {
                collapseToIdle()
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func startAnimating() {
        animationTimer?.invalidate()
        randomizeHeights()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                randomizeHeights()
            }
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        collapseToIdle()
    }

    private func randomizeHeights() {
        withAnimation(.easeInOut(duration: 0.25)) {
            barHeights = (0..<barCount).map { _ in
                CGFloat.random(in: minBarHeight...maxBarHeight)
            }
        }
    }

    private func collapseToIdle() {
        withAnimation(.easeInOut(duration: 0.4)) {
            barHeights = Array(repeating: minBarHeight, count: barCount)
        }
    }
}
