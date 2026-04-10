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
    private var commandProcessor: CommandProcessor?
    private var llmBackend: (any LLMBackend)?
    private var recordingStartTime: Date?
    private var isProcessing = false

    init(appState: AppState, modelManager: ModelManager, shortcutManager: ShortcutManager, dictionaryManager: DictionaryManager) {
        self.appState = appState
        self.modelManager = modelManager
        self.shortcutManager = shortcutManager
        self.dictionaryManager = dictionaryManager
    }

    func updateLLMBackend(_ backend: (any LLMBackend)?) {
        self.llmBackend = backend
        if let backend {
            commandProcessor = CommandProcessor(backend: backend)
            print("[Pipeline] LLM backend wired — command mode available")
        } else {
            commandProcessor = nil
            print("[Pipeline] LLM backend removed — command mode disabled")
        }
    }

    func start() {
        hotkeyService.onKeyDown = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.startRecording()
            }
        }

        hotkeyService.onKeyUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.stopRecordingAndTranscribe()
            }
        }

        hotkeyService.onCommandKeyDown = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.startCommandRecording()
            }
        }

        hotkeyService.onCommandKeyUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.stopCommandRecordingAndProcess()
            }
        }

        Task {
            await loadSelectedModel()
            await ensurePermissions()
            hotkeyService.start()
            print("[Pipeline] Started — model loaded: \(appState.isModelLoaded), accessibility: \(PermissionService.checkAccessibilityPermission())")
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
            return
        }

        do {
            try await transcriptionEngine.loadModel(path: modelPath.path)
            appState.isModelLoaded = true
            appState.errorMessage = nil
        } catch {
            appState.isModelLoaded = false
            appState.errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    private func startRecording() {
        print("[Pipeline] startRecording called — status: \(appState.status), isProcessing: \(isProcessing)")
        guard appState.status == .idle, !isProcessing else {
            print("[Pipeline] startRecording blocked — status: \(appState.status), isProcessing: \(isProcessing)")
            return
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
                preferredLanguage: appState.preferredLanguage,
                vocabularyWords: dictionaryManager.vocabularyWords
            )

            appState.detectedLanguage = result.language

            guard !result.text.isEmpty else {
                appState.status = .idle
                return
            }

            let minimalMode = SmartFormatter.shouldUseMinimalMode(setting: appState.minimalFormattingForEditors)
            var formatted = smartFormatter.format(result.text, modelId: appState.selectedModel, minimalMode: minimalMode)

            guard !formatted.isEmpty else {
                appState.status = .idle
                return
            }

            if appState.useLLMCleanup, let backend = llmBackend {
                appState.status = .cleaning
                formatted = await smartFormatter.cleanupWithLLM(formatted, backend: backend)
            }

            let corrected = dictionaryManager.applyCorrections(formatted)
            let expanded = shortcutManager.expand(corrected)

            appState.status = .injecting
            appState.lastTranscription = expanded
            appState.addTranscription(expanded, isCommand: false)
            TextInjector.inject(expanded, charByChar: appState.characterByCharacterMode)
            appState.status = .idle
        } catch {
            appState.status = .error
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
            scheduleErrorReset()
        }
    }

    // MARK: - Command Mode

    private func startCommandRecording() {
        print("[Pipeline] startCommandRecording called — status: \(appState.status), isProcessing: \(isProcessing)")
        guard appState.status == .idle, !isProcessing else {
            print("[Pipeline] startCommandRecording blocked — status: \(appState.status), isProcessing: \(isProcessing)")
            return
        }
        guard appState.commandModeEnabled else {
            print("[Pipeline] Command mode disabled in settings")
            return
        }
        guard commandProcessor != nil else {
            print("[Pipeline] Command processor is nil — LLM backend not wired")
            appState.errorMessage = "Download AI model in Settings → Formatting to enable command mode"
            return
        }
        isProcessing = true
        defer { if appState.status != .commandRecording { isProcessing = false } }
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
            appState.status = .commandRecording
            appState.isCommandMode = true
            recordingStartTime = Date()
        } catch {
            appState.status = .error
            appState.errorMessage = "Recording failed: \(error.localizedDescription)"
            appState.isCommandMode = false
            scheduleErrorReset()
        }
    }

    private func stopCommandRecordingAndProcess() async {
        guard appState.status == .commandRecording else { return }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let samples = audioRecorder.stopRecording()

        if duration < Constants.Audio.minimumRecordingDuration {
            appState.status = .idle
            appState.isCommandMode = false
            isProcessing = false
            return
        }

        appState.status = .commandTranscribing

        do {
            let language: String? = appState.autoDetectLanguage ? nil : appState.preferredLanguage
            let result = try await transcriptionEngine.transcribe(audioSamples: samples, language: language, preferredLanguage: appState.preferredLanguage)

            guard !result.text.isEmpty else {
                appState.status = .idle
                appState.isCommandMode = false
                isProcessing = false
                return
            }

            appState.lastCommand = result.text
            print("[Command] Transcribed command: \(result.text)")

            guard let selectedText = TextInjector.readSelection(), !selectedText.isEmpty else {
                print("[Command] Failed to read selection — no text selected")
                appState.errorMessage = "No text selected — select text before using command mode"
                appState.status = .error
                appState.isCommandMode = false
                isProcessing = false
                scheduleErrorReset()
                return
            }
            print("[Command] Selected text: \(selectedText.prefix(100))")

            appState.status = .commandProcessing

            guard let processor = commandProcessor else {
                print("[Command] Command processor is nil")
                appState.errorMessage = "Command processor not configured"
                appState.status = .error
                appState.isCommandMode = false
                isProcessing = false
                scheduleErrorReset()
                return
            }

            print("[Command] Sending to LLM...")
            let transformed = try await processor.process(command: result.text, selectedText: selectedText, parameters: appState.llmParameters)
            print("[Command] LLM result: \(transformed.prefix(200))")

            guard !transformed.isEmpty else {
                print("[Command] LLM returned empty — skipping")
                appState.status = .idle
                appState.isCommandMode = false
                isProcessing = false
                return
            }

            appState.status = .commandInjecting
            TextInjector.replaceSelection(transformed)
            appState.lastTranscription = transformed
            appState.addTranscription(transformed, isCommand: true)
            appState.status = .idle
            appState.isCommandMode = false
            isProcessing = false
        } catch {
            appState.status = .error
            appState.errorMessage = "Command processing failed: \(error.localizedDescription)"
            appState.isCommandMode = false
            isProcessing = false
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
            print("[Pipeline] WARNING: Accessibility not granted — hotkeys will not work")
        }
    }

    private func startAccessibilityPolling() {
        Task { @MainActor [weak self] in
            while let self, !PermissionService.checkAccessibilityPermission() {
                try? await Task.sleep(for: .seconds(2))
            }
            guard let self else { return }
            self.appState.errorMessage = nil
        }
    }

    private func scheduleErrorReset() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if self.appState.status == .error {
                self.appState.status = .idle
                self.appState.errorMessage = nil
            }
        }
    }
}
