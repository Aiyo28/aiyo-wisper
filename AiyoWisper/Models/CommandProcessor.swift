import Foundation

// MARK: - Phase 3: Voice command processing on selected text

struct CommandProcessor: Sendable {

    // MARK: - Dependencies

    private let backend: any LLMBackend

    init(backend: any LLMBackend) {
        self.backend = backend
    }

    // MARK: - Processing

    func process(command: String, selectedText: String, parameters: LLMParameters = LLMParameters()) async throws -> String {
        let userPrompt = """
            Command: \(command)

            Selected text:
            \(selectedText)
            """

        let result = try await backend.complete(
            systemPrompt: Constants.LLM.commandSystemPrompt,
            userPrompt: userPrompt,
            parameters: parameters
        )

        return stripWrappingQuotes(result.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Private Helpers

    /// Strips a single layer of wrapping quotes (double, single, or backticks) from the result.
    private func stripWrappingQuotes(_ text: String) -> String {
        let quotePairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("`", "`"),
        ]

        for (open, close) in quotePairs {
            if text.first == open, text.last == close, text.count >= 2 {
                let stripped = String(text.dropFirst().dropLast())
                return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }
}
