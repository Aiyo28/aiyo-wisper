import SwiftUI

@main
struct AiyoWisperApp: App {
    @State private var appState = AppState()
    @State private var modelManager = ModelManager()
    @State private var shortcutManager = ShortcutManager()
    @State private var dictionaryManager = DictionaryManager()
    @State private var learner = DictationLearner()
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
                updaterService: updaterService,
                shortcutManager: shortcutManager,
                dictionaryManager: dictionaryManager,
                learner: learner,
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

    private static func migrateAutoDetectLanguage() {
        let migrationKey = "didMigrateAutoDetectLanguage_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.autoDetectLanguage)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    @MainActor
    init() {
        Self.migrateAutoDetectLanguage()
        let state = _appState.wrappedValue
        let manager = _modelManager.wrappedValue
        let shortcuts = _shortcutManager.wrappedValue
        let dictionary = _dictionaryManager.wrappedValue
        let dictationLearner = _learner.wrappedValue
        let dictationPipeline = DictationPipeline(appState: state, modelManager: manager, shortcutManager: shortcuts, dictionaryManager: dictionary, learner: dictationLearner)

        _pipeline = State(initialValue: dictationPipeline)

        let recordingOverlay = _overlay.wrappedValue
        recordingOverlay.observe(state)

        if state.isOnboarded {
            dictationPipeline.start()
        } else {
            // NSApp is nil during SwiftUI App.init() — AppKit hasn't bootstrapped yet.
            // Defer the activate call to the next runloop tick when NSApplication.shared
            // is available. Activation is needed for LSUIElement apps to give the
            // onboarding window keyboard focus (the Window's .defaultLaunchBehavior
            // handles presentation, but not focus).
            DispatchQueue.main.async {
                NSApp?.activate(ignoringOtherApps: true)
            }
        }
    }
}
