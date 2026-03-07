import Foundation

// Phase 3: Trigger phrase expansion
@Observable
final class ShortcutManager {
    struct Shortcut: Codable, Identifiable {
        let id: UUID
        var trigger: String
        var expansion: String
    }

    private(set) var shortcuts: [Shortcut] = []

    func expand(_ text: String) -> String {
        text
    }
}
