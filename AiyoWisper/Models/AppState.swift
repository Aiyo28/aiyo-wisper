import SwiftUI

enum DictationStatus: String {
    case idle
    case recording
    case transcribing
    case cleaning
    case injecting
    case error
    case commandRecording
    case commandTranscribing
    case commandProcessing
    case commandInjecting
}

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let isCommand: Bool

    init(text: String, date: Date, isCommand: Bool) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.isCommand = isCommand
    }
}

@Observable
final class AppState {
    var status: DictationStatus = .idle
    var lastTranscription: String = ""
    var transcriptionHistory: [TranscriptionEntry] = []
    private static let maxHistoryEntries = 50
    var lastCommand: String = ""
    var errorMessage: String?
    var isCommandMode: Bool = false
    var isModelLoaded: Bool = false
    var modelLoadProgress: Double = 0
    var isDownloadingModel: Bool = false
    var downloadProgress: Double = 0

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.isOnboarded) var isOnboarded: Bool = false

    var selectedModel: String = Constants.Models.defaultModel {
        didSet { UserDefaults.standard.set(selectedModel, forKey: Constants.UserDefaultsKeys.selectedModel) }
    }

    var detectedLanguage: String?

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.preferredLanguage) var preferredLanguage: String = Constants.Language.defaultLanguage

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.autoDetectLanguage) var autoDetectLanguage: Bool = true

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.minimalFormattingForEditors) var minimalFormattingForEditors: Bool = true

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.useLLMCleanup) var useLLMCleanup: Bool = true

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.commandModeEnabled) var commandModeEnabled: Bool = true

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.characterByCharacterMode) var characterByCharacterMode: Bool = false

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.llmTemperature) var llmTemperature: Double = Constants.LLM.defaultTemperature

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.llmMaxTokens) var llmMaxTokens: Int = Constants.LLM.defaultMaxTokens

    var llmParameters: LLMParameters {
        LLMParameters(
            temperature: llmTemperature,
            maxTokens: llmMaxTokens
        )
    }

    var isRecordingAny: Bool { status == .recording || status == .commandRecording }

    init() {
        if let stored = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedModel) {
            selectedModel = stored
        }
        loadHistory()
    }

    func addTranscription(_ text: String, isCommand: Bool) {
        let entry = TranscriptionEntry(text: text, date: Date(), isCommand: isCommand)
        transcriptionHistory.insert(entry, at: 0)
        if transcriptionHistory.count > Self.maxHistoryEntries {
            transcriptionHistory.removeLast()
        }
        saveHistory()
    }

    func clearHistory() {
        transcriptionHistory.removeAll()
        saveHistory()
    }

    // MARK: - History Persistence

    private func loadHistory() {
        let url = Constants.History.historyFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
            transcriptionHistory = Array(entries.prefix(Constants.History.maxPersistentEntries))
        } catch {
            print("[AppState] Failed to load history: \(error)")
        }
    }

    private func saveHistory() {
        let url = Constants.History.historyFileURL
        let entriesToSave = Array(transcriptionHistory.prefix(Constants.History.maxPersistentEntries))
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entriesToSave)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[AppState] Failed to save history: \(error)")
        }
    }
}
