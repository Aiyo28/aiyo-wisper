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
        case .recording, .transcribing, .error:
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
            // NSAnimationContext invokes completion on the main thread, but the closure
            // type is @Sendable so the compiler can't infer MainActor isolation. Hop
            // back explicitly to touch `panel.orderOut` and the @MainActor `hostingView`.
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                self?.hostingView?.rootView = RecordingOverlayContent(status: .idle)
            }
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

    private var isRecording: Bool {
        status == .recording
    }

    private var isError: Bool {
        status == .error
    }

    /// Pill background tint shifts to a warning red when something failed so the
    /// user has an unmistakable visual cue alongside the menu-bar error message.
    /// Without this, an error state previously hid the overlay completely and the
    /// failure was visually identical to a successful but silent dictation.
    private var pillFill: Color {
        isError ? Color(red: 0.55, green: 0.10, blue: 0.10).opacity(0.92)
                : Color.black.opacity(0.85)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(pillFill)
            .frame(width: 120, height: 44)
            .overlay {
                if isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                } else {
                    WaveformView(isRecording: isRecording)
                }
            }
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let isRecording: Bool

    private let barCount = 9
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3
    private let maxBarHeight: CGFloat = 20
    private let minBarHeight: CGFloat = 4

    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 9)
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
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
