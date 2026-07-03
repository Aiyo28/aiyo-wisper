import SwiftUI

enum DictationStatus: String {
    case idle
    case recording
    case transcribing
    case injecting
    case error
}

/// Which speech-to-text backend the pipeline uses.
///
/// - `apple`: Apple's on-device `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26+).
///   No app-managed model download, locale-pinned (no language bleed), lowest latency.
///   The default for v1.2.0.
/// - `whisperKit`: The original WhisperKit CoreML backend. Kept as an opt-in fallback
///   for users who prefer it or need a locale Apple doesn't ship on-device.
enum TranscriptionEngineKind: String, CaseIterable, Identifiable {
    case apple
    case whisperKit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple (built-in)"
        case .whisperKit: "WhisperKit"
        }
    }

    var blurb: String {
        switch self {
        case .apple: "On-device, no download, fastest. Recommended."
        case .whisperKit: "Downloadable CoreML models. Use if you need a specific model."
        }
    }
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

    /// Selected speech-to-text backend. Stored as a raw string; exposed as the typed
    /// `transcriptionEngine` below so views bind to the enum directly.
    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.transcriptionEngine) private var transcriptionEngineRaw: String = TranscriptionEngineKind.apple.rawValue

    var transcriptionEngine: TranscriptionEngineKind {
        get { TranscriptionEngineKind(rawValue: transcriptionEngineRaw) ?? .apple }
        set { transcriptionEngineRaw = newValue.rawValue }
    }

    /// When on, transcripts are cleaned up by Apple's on-device Foundation Models LLM
    /// (punctuation, capitalization, false-start removal) instead of the rule-based
    /// formatter. Falls back to rules automatically when the model is unavailable.
    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.useAIFormatting) var useAIFormatting: Bool = true

    /// Runtime flag (not persisted): whether the Foundation Models on-device LLM is
    /// actually usable on this Mac right now. Set once at startup by the pipeline.
    var aiFormattingAvailable: Bool = false

    /// App languages Apple's on-device engine currently supports on this Mac. The language
    /// pickers offer exactly these (plus Auto) when the Apple engine is active, so we never
    /// present a language that would just fail. Grows automatically as macOS adds locales —
    /// English is always present. WhisperKit ignores this (it's multilingual).
    var appleSupportedLanguages: [String] = [Constants.Language.defaultLanguage]

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
