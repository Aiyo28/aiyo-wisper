import Foundation

@MainActor
final class DictationPipeline {
    private let appState: AppState
    private let audioRecorder = AudioRecorder()
    private let transcriptionEngine = TranscriptionEngine()
    private let hotkeyService = HotkeyService()
    private let modelManager: ModelManager
    private let smartFormatter = SmartFormatter()
    private var recordingStartTime: Date?
    private var isProcessing = false

    init(appState: AppState, modelManager: ModelManager) {
        self.appState = appState
        self.modelManager = modelManager
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

            appState.status = .injecting
            appState.lastTranscription = formatted
            TextInjector.inject(formatted)
            appState.status = .idle
        } catch {
            appState.status = .error
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
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
