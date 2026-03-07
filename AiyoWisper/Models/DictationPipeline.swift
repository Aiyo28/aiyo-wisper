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
    private var commandProcessor: CommandProcessor?
    private var recordingStartTime: Date?
    private var isProcessing = false

    init(appState: AppState, modelManager: ModelManager, shortcutManager: ShortcutManager) {
        self.appState = appState
        self.modelManager = modelManager
        self.shortcutManager = shortcutManager
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

        updateLLMSettings()

        Task {
            await loadSelectedModel()
            hotkeyService.start()
        }
    }

    func stop() {
        hotkeyService.stop()
    }

    func loadSelectedModel() async {
        let modelName = appState.selectedModel
        guard let modelPath = modelManager.modelPath(for: modelName) else {
            appState.isModelLoaded = false
            return
        }

        do {
            try await transcriptionEngine.loadModel(path: modelPath.path())
            appState.isModelLoaded = true
        } catch {
            appState.isModelLoaded = false
            appState.errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    private func startRecording() {
        guard appState.status == .idle, !isProcessing else { return }
        isProcessing = true
        defer { if appState.status != .recording { isProcessing = false } }
        guard appState.isModelLoaded else {
            appState.errorMessage = "Model is still loading, please wait..."
            return
        }
        guard PermissionService.checkMicrophonePermission() else {
            appState.errorMessage = "Microphone permission not granted"
            return
        }
        guard PermissionService.checkAccessibilityPermission() else {
            appState.errorMessage = "Accessibility permission not granted"
            return
        }

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

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let samples = audioRecorder.stopRecording()

        if duration < Constants.Audio.minimumRecordingDuration {
            appState.status = .idle
            return
        }

        appState.status = .transcribing

        do {
            let language: String? = appState.autoDetectLanguage ? nil : appState.preferredLanguage
            let result = try await transcriptionEngine.transcribe(audioSamples: samples, language: language)

            appState.detectedLanguage = result.language

            guard !result.text.isEmpty else {
                appState.status = .idle
                return
            }

            let minimalMode = SmartFormatter.shouldUseMinimalMode(setting: appState.minimalFormattingForEditors)
            let formatted = smartFormatter.format(result.text, modelId: appState.selectedModel, minimalMode: minimalMode)

            guard !formatted.isEmpty else {
                appState.status = .idle
                return
            }

            let expanded = shortcutManager.expand(formatted)

            appState.status = .injecting
            appState.lastTranscription = expanded
            TextInjector.inject(expanded)
            appState.status = .idle
        } catch {
            appState.status = .error
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
            scheduleErrorReset()
        }
    }

    // MARK: - LLM Settings

    func reloadLLMService() {
        updateLLMSettings()
    }

    func updateLLMSettings() {
        let endpoint = appState.llmEndpoint
        let model = appState.llmModel
        guard !endpoint.isEmpty, !model.isEmpty else {
            commandProcessor = nil
            return
        }
        let llmService = LLMService(endpointURL: endpoint, modelName: model)
        commandProcessor = CommandProcessor(llmService: llmService)
    }

    // MARK: - Command Mode

    private func startCommandRecording() {
        guard appState.status == .idle, !isProcessing else { return }
        guard appState.commandModeEnabled else { return }
        guard commandProcessor != nil else {
            appState.errorMessage = "Command mode requires LLM settings to be configured"
            return
        }
        isProcessing = true
        defer { if appState.status != .commandRecording { isProcessing = false } }
        guard appState.isModelLoaded else {
            appState.errorMessage = "Model is still loading, please wait..."
            return
        }
        guard PermissionService.checkMicrophonePermission() else {
            appState.errorMessage = "Microphone permission not granted"
            return
        }
        guard PermissionService.checkAccessibilityPermission() else {
            appState.errorMessage = "Accessibility permission not granted"
            return
        }

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
            let result = try await transcriptionEngine.transcribe(audioSamples: samples, language: language)

            guard !result.text.isEmpty else {
                appState.status = .idle
                appState.isCommandMode = false
                isProcessing = false
                return
            }

            appState.lastCommand = result.text

            guard let selectedText = TextInjector.readSelection(), !selectedText.isEmpty else {
                appState.errorMessage = "No text selected — select text before using command mode"
                appState.status = .error
                appState.isCommandMode = false
                isProcessing = false
                scheduleErrorReset()
                return
            }

            appState.status = .commandProcessing

            guard let processor = commandProcessor else {
                appState.errorMessage = "Command processor not configured"
                appState.status = .error
                appState.isCommandMode = false
                isProcessing = false
                scheduleErrorReset()
                return
            }

            let transformed = try await processor.process(command: result.text, selectedText: selectedText)

            guard !transformed.isEmpty else {
                appState.status = .idle
                appState.isCommandMode = false
                isProcessing = false
                return
            }

            appState.status = .commandInjecting
            TextInjector.replaceSelection(transformed)
            appState.lastTranscription = transformed
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
