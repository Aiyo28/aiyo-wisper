import Foundation

// Phase 3: Trigger phrase expansion
@Observable
final class ShortcutManager {
    struct Shortcut: Codable, Identifiable, Sendable {
        let id: UUID
        var trigger: String
        var expansion: String
        let createdAt: Date

        init(id: UUID = UUID(), trigger: String, expansion: String, createdAt: Date = Date()) {
            self.id = id
            self.trigger = trigger
            self.expansion = expansion
            self.createdAt = createdAt
        }
    }

    private(set) var shortcuts: [Shortcut] = []

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("AiyoWisper", isDirectory: true)
            .appendingPathComponent("shortcuts.json")
    }

    init() {
        load()
    }

    // MARK: - CRUD

    func addShortcut(trigger: String, expansion: String) {
        let shortcut = Shortcut(trigger: trigger, expansion: expansion)
        shortcuts.append(shortcut)
        save()
    }

    func updateShortcut(id: UUID, trigger: String, expansion: String) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        shortcuts[index].trigger = trigger
        shortcuts[index].expansion = expansion
        save()
    }

    func deleteShortcut(id: UUID) {
        shortcuts.removeAll { $0.id == id }
        save()
    }

    func moveShortcuts(from source: IndexSet, to destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Expansion

    func expand(_ text: String) -> String {
        guard !shortcuts.isEmpty else { return text }

        // Sort triggers by length descending to avoid partial matches
        let sorted = shortcuts.sorted { $0.trigger.count > $1.trigger.count }

        var result = text
        for shortcut in sorted {
            let escapedTrigger = NSRegularExpression.escapedPattern(for: shortcut.trigger)
            let pattern = "\\b\(escapedTrigger)\\b"
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) else { continue }

            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: shortcut.expansion)
            )
        }
        return result
    }

    // MARK: - Persistence

    private func load() {
        let directory = storageURL.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        guard fm.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            shortcuts = try decoder.decode([Shortcut].self, from: data)
        } catch {
            shortcuts = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(shortcuts)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Silently fail — persistence is best-effort
        }
    }
}
