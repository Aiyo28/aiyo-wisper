import ApplicationServices
import Cocoa
import Foundation

struct CorrectionSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let original: String
    let suggested: String
    let detectedAt: Date
    let contextApp: String

    init(original: String, suggested: String, contextApp: String) {
        self.id = UUID()
        self.original = original
        self.suggested = suggested
        self.detectedAt = Date()
        self.contextApp = contextApp
    }
}

/// Observes the focused text field after dictation injection. If the user backspaces
/// the dictated text and types a slightly different word, surface that as a correction
/// suggestion the user can one-click accept into the Dictionary.
///
/// Heuristic-only — no model. False positives are dismissable in Settings → Dictionary.
@MainActor
@Observable
final class DictationLearner {
    private(set) var suggestions: [CorrectionSuggestion] = []

    private var pending: PendingObservation?
    private var observationTask: Task<Void, Never>?

    /// Maximum number of pending suggestions. Older ones get dropped first.
    private let maxSuggestions = 30

    private struct PendingObservation {
        let injectedText: String
        let preStateText: String
        let element: AXUIElement
        let appBundleID: String
    }

    init() {
        loadSuggestions()
    }

    // MARK: - Public API

    /// Call immediately BEFORE injecting dictated text. Captures the focused field's
    /// current value so we can diff what changed afterward.
    func captureInjection(injectedText: String) {
        observationTask?.cancel()
        let trimmed = injectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }
        guard let element = focusedElement() else { return }

        // Mirror the finalize() role/secure gates here so we never capture preStateText
        // from a sensitive field even briefly.
        guard let role = stringAttribute(of: element, name: kAXRoleAttribute as CFString),
              allowedTextRoles.contains(role) else { return }
        if let desc = stringAttribute(of: element, name: kAXRoleDescriptionAttribute as CFString),
           desc.localizedCaseInsensitiveContains("secure") { return }
        if let subrole = stringAttribute(of: element, name: kAXSubroleAttribute as CFString),
           subrole == (kAXSecureTextFieldSubrole as String) { return }

        let preText = textValue(of: element) ?? ""
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

        pending = PendingObservation(
            injectedText: trimmed,
            preStateText: preText,
            element: element,
            appBundleID: bundleID
        )

        observationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Constants.Dictionary.observationDelay))
            self?.finalize()
        }
    }

    func acceptSuggestion(_ id: UUID, dictionaryManager: DictionaryManager) {
        guard let s = suggestions.first(where: { $0.id == id }) else { return }
        dictionaryManager.addEntry(word: s.original, correction: s.suggested)
        suggestions.removeAll { $0.id == id }
        saveSuggestions()
    }

    func dismissSuggestion(_ id: UUID) {
        suggestions.removeAll { $0.id == id }
        saveSuggestions()
    }

    func clearAllSuggestions() {
        suggestions.removeAll()
        saveSuggestions()
    }

    // MARK: - Finalize / diff

    /// Re-reads the focused field 12s after injection and diffs against what we typed.
    /// Multiple safety gates prevent reading data the user never intended us to see:
    /// (1) the focus must still be on the same element we observed at injection time,
    /// (2) the element must be a text-bearing role (no buttons, no system UI), and
    /// (3) password / secure-text fields are refused outright.
    private func finalize() {
        defer { pending = nil }
        guard let p = pending else { return }

        // Bail if the user switched focus away. A different element 12s later could be
        // a password field, a banking app, a chat message in another app — none of
        // which we have any business reading just because we dictated earlier.
        guard let currentlyFocused = focusedElement(),
              CFEqual(currentlyFocused, p.element) else { return }

        // The element must still be a regular text input. Roles we accept:
        // AXTextField, AXTextArea, AXComboBox. Anything else is silently dropped.
        guard let role = stringAttribute(of: p.element, name: kAXRoleAttribute as CFString),
              allowedTextRoles.contains(role) else { return }

        // Refuse secure text fields explicitly — role description is the most reliable
        // signal across native and Catalyst apps.
        if let desc = stringAttribute(of: p.element, name: kAXRoleDescriptionAttribute as CFString),
           desc.localizedCaseInsensitiveContains("secure") {
            return
        }
        if let subrole = stringAttribute(of: p.element, name: kAXSubroleAttribute as CFString),
           subrole == (kAXSecureTextFieldSubrole as String) {
            return
        }

        guard let postText = textValue(of: p.element) else { return }

        let newOnes = computeSuggestions(
            injected: p.injectedText,
            pre: p.preStateText,
            post: postText,
            app: p.appBundleID
        )
        guard !newOnes.isEmpty else { return }
        mergeSuggestions(newOnes)
    }

    private let allowedTextRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
    ]

    /// Word-level positional comparison anchored on the prefix shared between pre and post
    /// state. Returns substitutions where injected word X was replaced by similar word Y.
    private func computeSuggestions(injected: String, pre: String, post: String, app: String) -> [CorrectionSuggestion] {
        // Strip the prefix the user didn't touch — what remains in `post` is what's after
        // the injection point (approximately).
        let prefixLen = commonPrefixLength(pre, post)
        let postDelta = String(post.dropFirst(prefixLen)).trimmingCharacters(in: .whitespacesAndNewlines)

        // If the user wiped most of the injection, don't try to learn — they rejected it.
        guard !postDelta.isEmpty,
              Double(postDelta.count) > Double(injected.count) * 0.4 else {
            return []
        }

        let originalWords = wordSplit(injected)
        let editedWords = wordSplit(postDelta)

        var out: [CorrectionSuggestion] = []
        for (i, orig) in originalWords.enumerated() {
            guard i < editedWords.count else { break }
            let edited = editedWords[i]
            guard orig.count >= 3, edited.count >= 3 else { continue }
            guard orig != edited else { continue }
            // Cap length delta — wholesale rewrites aren't corrections.
            guard abs(orig.count - edited.count) <= 3 else { continue }
            let dist = levenshtein(orig.lowercased(), edited.lowercased())
            // 1-3 captures typos, missing chars, casing fixes. >3 is a different word entirely.
            guard dist >= 1, dist <= 3 else { continue }
            out.append(CorrectionSuggestion(original: orig, suggested: edited, contextApp: app))
        }
        return out
    }

    private func mergeSuggestions(_ new: [CorrectionSuggestion]) {
        for s in new {
            // Dedupe on the (original, suggested) pair.
            if suggestions.contains(where: {
                $0.original.lowercased() == s.original.lowercased()
                    && $0.suggested.lowercased() == s.suggested.lowercased()
            }) { continue }
            suggestions.append(s)
        }
        if suggestions.count > maxSuggestions {
            suggestions.removeFirst(suggestions.count - maxSuggestions)
        }
        saveSuggestions()
    }

    // MARK: - AX helpers

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let raw = focused else { return nil }
        // swiftlint:disable:next force_cast
        return (raw as! AXUIElement)
    }

    private func textValue(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard result == .success, let str = value as? String else { return nil }
        return str
    }

    private func stringAttribute(of element: AXUIElement, name: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name, &value)
        guard result == .success, let str = value as? String else { return nil }
        return str
    }

    // MARK: - String helpers

    private func wordSplit(_ s: String) -> [String] {
        s.split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
    }

    private func commonPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (x, y) in zip(a, b) {
            if x == y { count += 1 } else { break }
        }
        return count
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[t.count]
    }

    // MARK: - Persistence

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AiyoWisper/dictionary_suggestions.json", isDirectory: false)
    }

    private func loadSuggestions() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            suggestions = try JSONDecoder().decode([CorrectionSuggestion].self, from: data)
        } catch {
            Log.learner.error("Failed to load: \(error)")
        }
    }

    private func saveSuggestions() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(suggestions)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            Log.learner.error("Failed to save: \(error)")
        }
    }
}
