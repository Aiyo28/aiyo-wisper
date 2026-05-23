import AVFAudio
import Foundation

@MainActor
final class DictationPipeline {
    private let appState: AppState
    private let audioRecorder = AudioRecorder()
    private let transcriptionEngine = TranscriptionEngine()
    private let hotkeyService = HotkeyService()
    private let modelManager: ModelManager
    private let smartFormatter = SmartFormatter()
    private let shortcutManager: ShortcutManager
    private let dictionaryManager: DictionaryManager
    private let learner: DictationLearner
    private var recordingStartTime: Date?
    private var isProcessing = false
    /// Idempotency guard for start(). OnboardingView fires onComplete?() from both
    /// step-4 .onAppear and the Finish button, so start() can be called twice in
    /// quick succession — without this guard, the second call would spawn a parallel
    /// loadSelectedModel() Task racing against the first.
    private var hasStarted = false

    init(appState: AppState, modelManager: ModelManager, shortcutManager: ShortcutManager, dictionaryManager: DictionaryManager, learner: DictationLearner) {
        self.appState = appState
        self.modelManager = modelManager
        self.shortcutManager = shortcutManager
        self.dictionaryManager = dictionaryManager
        self.learner = learner
    }

    func start() {
        guard !hasStarted else {
            Log.pipeline.info("start() called twice — ignoring (already running)")
            return
        }
        hasStarted = true

        hotkeyService.onKeyDown = { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.startRecording() }
        }

        hotkeyService.onKeyUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.stopRecordingAndTranscribe() }
        }

        Task {
            await loadSelectedModel()
            await ensurePermissions()
            hotkeyService.start()
            Log.pipeline.info("Started — model loaded: \(self.appState.isModelLoaded, privacy: .public), accessibility: \(PermissionService.checkAccessibilityPermission(), privacy: .public)")
        }
    }

    func stop() {
        hotkeyService.stop()
    }

    func loadSelectedModel() async {
        let modelName = appState.selectedModel
        guard let modelPath = modelManager.modelPath(for: modelName) else {
            appState.isModelLoaded = false
            appState.errorMessage = "Model \"\(modelName)\" not downloaded — open Settings → Transcription to download"
            Log.pipeline.info("loadSelectedModel: no on-disk path for '\(modelName, privacy: .public)'")
            return
        }

        Log.pipeline.info("Loading Whisper model '\(modelName, privacy: .public)' from \(modelPath.path, privacy: .public)")
        let loadStart = Date()
        do {
            try await transcriptionEngine.loadModel(path: modelPath.path)
            let elapsed = Date().timeIntervalSince(loadStart)
            appState.isModelLoaded = true
            appState.errorMessage = nil
            Log.pipeline.info("Model '\(modelName, privacy: .public)' loaded successfully in \(String(format: "%.1f", elapsed), privacy: .public)s")
        } catch {
            let elapsed = Date().timeIntervalSince(loadStart)
            appState.isModelLoaded = false
            appState.errorMessage = "Failed to load model: \(error.localizedDescription)"
            Log.pipeline.error("Model '\(modelName, privacy: .public)' load FAILED after \(String(format: "%.1f", elapsed), privacy: .public)s: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startRecording() {
        Log.pipeline.info("startRecording called — status: \(self.appState.status.rawValue, privacy: .public), isProcessing: \(self.isProcessing, privacy: .public)")
        guard appState.status == .idle else {
            Log.pipeline.info("startRecording blocked — status: \(self.appState.status.rawValue, privacy: .public)")
            return
        }
        if isProcessing {
            // Recovery: if stuck processing for >10s, force reset. Belt-and-suspenders
            // for the now-fixed isProcessing-leak bug.
            if let start = recordingStartTime, Date().timeIntervalSince(start) > 10 {
                Log.pipeline.info("Force-resetting stale isProcessing flag")
                isProcessing = false
            } else {
                Log.pipeline.info("startRecording blocked — isProcessing: true")
                return
            }
        }

        isProcessing = true
        defer { if appState.status != .recording { isProcessing = false } }

        guard appState.isModelLoaded else {
            if modelManager.modelPath(for: appState.selectedModel) == nil {
                appState.errorMessage = "Model \"\(appState.selectedModel)\" not downloaded — open Settings → Transcription to download"
            } else {
                appState.errorMessage = "Model is still loading, please wait..."
            }
            return
        }
        guard PermissionService.checkMicrophonePermission() else {
            appState.errorMessage = "Microphone permission not granted"
            scheduleErrorReset()
            return
        }
        guard PermissionService.checkAccessibilityPermission() else {
            appState.errorMessage = "Accessibility permission not working — if already enabled, toggle it OFF then ON in System Settings → Privacy & Security → Accessibility"
            PermissionService.openAccessibilitySettings()
            startAccessibilityPolling()
            return
        }

        appState.errorMessage = nil

        do {
            try audioRecorder.startRecording()
            appState.status = .recording
            recordingStartTime = Date()
        } catch {
            appState.status = .error
            appState.errorMessage = "Recording failed: \(error.localizedDescription)"
            scheduleErrorReset()
        }
    }

    private func stopRecordingAndTranscribe() async {
        guard appState.status == .recording else { return }
        defer { isProcessing = false }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let samples = audioRecorder.stopRecording()

        if duration < Constants.Audio.minimumRecordingDuration {
            appState.status = .idle
            return
        }

        appState.status = .transcribing

        do {
            let language: String? = appState.autoDetectLanguage ? nil : appState.preferredLanguage
            let result = try await transcriptionEngine.transcribe(
                audioSamples: samples,
                language: language,
                vocabularyWords: dictionaryManager.vocabularyWords
            )

            appState.detectedLanguage = result.language

            guard !result.text.isEmpty else {
                // Product principle: flow > correctness. When Whisper produces no usable
                // output (either genuine silence or structural-token-only — both signal
                // "I couldn't decode this"), we go SILENT back to idle. No red pill, no
                // error banner, no menu-bar alarm. The user can press the hotkey again
                // immediately without having to dismiss anything. Logs still capture the
                // failure for diagnosis.
                Log.pipeline.info("Transcribe returned empty for \(String(format: "%.1f", duration), privacy: .public)s clip (stripped=\(result.strippedCount, privacy: .public)) — silent idle")
                appState.status = .idle
                return
            }

            let minimalMode = SmartFormatter.shouldUseMinimalMode(setting: appState.minimalFormattingForEditors)
            let formatted = smartFormatter.format(result.text, modelId: appState.selectedModel, minimalMode: minimalMode)

            guard !formatted.isEmpty else {
                // Same silent-fail policy: the regex passes nuked the transcript to
                // nothing. Worth a log line for future tuning, but no UI interruption.
                Log.pipeline.info("SmartFormatter reduced transcript to empty (in=\(result.text.count, privacy: .public) chars) — silent idle")
                appState.status = .idle
                return
            }

            let corrected = dictionaryManager.applyCorrections(formatted)
            let expanded = shortcutManager.expand(corrected)

            appState.status = .injecting
            appState.lastTranscription = expanded
            appState.addTranscription(expanded)
            // Capture focused field state BEFORE injection so the learner can diff after.
            learner.captureInjection(injectedText: expanded)
            let injected = await TextInjector.inject(expanded, charByChar: appState.characterByCharacterMode)
            if !injected {
                Log.pipeline.info("Inject blocked — accessibility permission missing (\(expanded.count, privacy: .public) chars)")
                appState.errorMessage = "Accessibility permission required to paste — open System Settings → Privacy & Security → Accessibility"
                appState.status = .error
                scheduleErrorReset()
                return
            }
            appState.status = .idle
        } catch {
            appState.status = .error
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
            scheduleErrorReset()
        }
    }

    private func ensurePermissions() async {
        if !PermissionService.checkMicrophonePermission() {
            await AVAudioApplication.requestRecordPermission()
        }
        if !PermissionService.promptAccessibilityPermission() {
            appState.errorMessage = "Accessibility permission not working — if already enabled, toggle it OFF then ON in System Settings → Privacy & Security → Accessibility"
            PermissionService.openAccessibilitySettings()
            startAccessibilityPolling()
            Log.pipeline.info("WARNING: Accessibility not granted — hotkeys will not work")
        }
    }

    private func startAccessibilityPolling() {
        Task { @MainActor [weak self] in
            while !PermissionService.checkAccessibilityPermission() {
                try? await Task.sleep(for: .seconds(2))
                if self == nil { return }
            }
            guard let self else { return }
            self.appState.errorMessage = nil
        }
    }

    /// Resets `status` from `.error` back to `.idle` after a short delay so the
    /// user can press the hotkey again — but does NOT clear `errorMessage`. The
    /// message remains visible in the menu bar until the next successful dictation
    /// (or the next recording attempt clears it explicitly at line 126).
    ///
    /// Pre-audit behavior cleared both after 3s; in practice users were missing the
    /// 3-second flash and seeing "nothing happened" as a result. Decoupling lifetimes
    /// gives the message dwell-time without blocking retry.
    private func scheduleErrorReset() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            if self.appState.status == .error {
                self.appState.status = .idle
            }
        }
    }
}
