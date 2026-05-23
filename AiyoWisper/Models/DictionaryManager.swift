import Foundation

struct DictionaryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var word: String
    var correction: String?
    let createdAt: Date

    init(word: String, correction: String? = nil) {
        self.id = UUID()
        self.word = word
        self.correction = correction
        self.createdAt = Date()
    }
}

@Observable
final class DictionaryManager {
    private(set) var entries: [DictionaryEntry] = []

    init() {
        loadEntries()
    }

    // MARK: - CRUD

    func addEntry(word: String, correction: String?) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        let trimmedCorrection = correction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = DictionaryEntry(
            word: trimmedWord,
            correction: trimmedCorrection?.isEmpty == true ? nil : trimmedCorrection
        )
        entries.append(entry)
        saveEntries()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    // MARK: - Vocabulary Words (for Whisper biasing)

    var vocabularyWords: [String] {
        entries.map { entry in
            // For corrections, bias toward the correct form
            entry.correction ?? entry.word
        }
    }

    // MARK: - Post-Transcription Corrections

    func applyCorrections(_ text: String) -> String {
        var result = text
        for entry in entries {
            guard let correction = entry.correction else { continue }
            // Case-insensitive word boundary replacement
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: correction
            )
        }
        return result
    }

    // MARK: - Persistence

    private func loadEntries() {
        let url = Constants.Dictionary.dictionaryFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        } catch {
            Log.dictionary.error("Failed to load: \(error)")
        }
    }

    private func saveEntries() {
        let url = Constants.Dictionary.dictionaryFileURL
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            Log.dictionary.error("Failed to save: \(error)")
        }
    }
}
