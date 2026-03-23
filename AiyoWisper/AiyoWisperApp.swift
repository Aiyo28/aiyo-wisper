import SwiftUI

@main
struct AiyoWisperApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()
    @State private var shortcutManager = ShortcutManager()
    @State private var dictionaryManager = DictionaryManager()
    @State private var pipeline: DictationPipeline?
    @State private var overlay = RecordingOverlay()
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
        .defaultLaunchBehavior(appState.isOnboarded ? .suppressed : .presented)

        Settings {
            SettingsView(
                appState: appState,
                modelManager: modelManager,
                shortcutManager: shortcutManager,
                dictionaryManager: dictionaryManager,
                onModelSelected: {
                    Task {
                        await pipeline?.loadSelectedModel()
                    }
                },
                onLLMSettingsChanged: {
                    pipeline?.updateLLMSettings()
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
        let shortcuts = _shortcutManager.wrappedValue
        let dictionary = _dictionaryManager.wrappedValue
        let dictationPipeline = DictationPipeline(appState: state, modelManager: manager, shortcutManager: shortcuts, dictionaryManager: dictionary)
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
