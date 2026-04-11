import SwiftUI

@main
struct AiyoWisperApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()
    @State private var llmModelManager = LLMModelManager()
    @State private var shortcutManager = ShortcutManager()
    @State private var dictionaryManager = DictionaryManager()
    @State private var pipeline: DictationPipeline?
    @State private var overlay = RecordingOverlay()
    @StateObject private var updaterService = UpdaterService()

    var body: some Scene {
        MenuBarExtra("AIYO Wisper", systemImage: menuBarIcon) {
            MenuBarView(appState: appState, modelManager: modelManager, updaterService: updaterService)
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
        .defaultLaunchBehavior(appState.isOnboarded ? .suppressed : .presented)

        Settings {
            SettingsView(
                appState: appState,
                modelManager: modelManager,
                llmModelManager: llmModelManager,
                updaterService: updaterService,
                shortcutManager: shortcutManager,
                dictionaryManager: dictionaryManager,
                onModelSelected: {
                    Task {
                        await pipeline?.loadSelectedModel()
                    }
                },
                onLLMModelChanged: {
                    updateLLMBackend()
                }
            )
        }
    }

    private var menuBarIcon: String {
        switch appState.status {
        case .recording, .commandRecording: "mic.fill"
        case .transcribing, .cleaning, .commandTranscribing, .commandProcessing: "ellipsis.circle"
        default: "waveform"
        }
    }

    private func updateLLMBackend() {
        if let path = llmModelManager.modelPath {
            let backend = LocalLLMBackend(modelPath: path)
            pipeline?.updateLLMBackend(backend)
        } else {
            pipeline?.updateLLMBackend(nil)
        }
    }

    private static func migrateAutoDetectLanguage() {
        let migrationKey = "didMigrateAutoDetectLanguage_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.autoDetectLanguage)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    init() {
        Self.migrateAutoDetectLanguage()
        let state = _appState.wrappedValue
        let manager = _modelManager.wrappedValue
        let llmManager = _llmModelManager.wrappedValue
        let shortcuts = _shortcutManager.wrappedValue
        let dictionary = _dictionaryManager.wrappedValue
        let dictationPipeline = DictationPipeline(appState: state, modelManager: manager, shortcutManager: shortcuts, dictionaryManager: dictionary)

        if let path = llmManager.modelPath {
            let backend = LocalLLMBackend(modelPath: path)
            dictationPipeline.updateLLMBackend(backend)
        }

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
