import SwiftUI

@main
struct AiyoWisperApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()
    @State private var pipeline: DictationPipeline?
    @State private var overlay = RecordingOverlay()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("AIYO Wisper", systemImage: menuBarIcon) {
            MenuBarView(appState: appState, modelManager: modelManager)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to AIYO Wisper", id: "onboarding") {
            OnboardingView(
                appState: appState,
                modelManager: modelManager,
                onComplete: {
                    pipeline?.start()
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(
                appState: appState,
                modelManager: modelManager,
                onModelSelected: {
                    Task {
                        await pipeline?.loadSelectedModel()
                    }
                }
            )
        }
    }

    private var menuBarIcon: String {
        switch appState.status {
        case .recording: "mic.fill"
        case .transcribing: "ellipsis.circle"
        default: "waveform"
        }
    }

    init() {
        let state = _appState.wrappedValue
        let manager = _modelManager.wrappedValue
        let dictationPipeline = DictationPipeline(appState: state, modelManager: manager)
        _pipeline = State(initialValue: dictationPipeline)

        let recordingOverlay = _overlay.wrappedValue
        recordingOverlay.observe(state)

        if state.isOnboarded {
            DispatchQueue.main.async {
                dictationPipeline.start()
            }
        } else {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
