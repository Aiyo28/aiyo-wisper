import SwiftUI

enum DictationStatus: String {
    case idle
    case recording
    case transcribing
    case injecting
    case error
}

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    /// Legacy field — older history entries carried this from the command-mode era.
    /// Kept as an optional Codable field so persisted JSON still decodes; new entries
    /// don't populate it.
    let isCommand: Bool?

    init(text: String, date: Date) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.isCommand = nil
    }
}

@Observable
final class AppState {
    var status: DictationStatus = .idle
    var lastTranscription: String = ""
    var transcriptionHistory: [TranscriptionEntry] = []
    private static let maxHistoryEntries = 50
    var errorMessage: String?
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
    @AppStorage(Constants.UserDefaultsKeys.characterByCharacterMode) var characterByCharacterMode: Bool = false

    var isRecordingAny: Bool { status == .recording }

    init() {
        if let stored = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedModel) {
            selectedModel = stored
        }
        loadHistory()
    }

    func addTranscription(_ text: String) {
        let entry = TranscriptionEntry(text: text, date: Date())
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
            Log.appstate.error("Failed to load history: \(error)")
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
            Log.appstate.error("Failed to save history: \(error)")
        }
    }
}
