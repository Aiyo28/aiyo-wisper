import Foundation

// MARK: - Phase 3: Voice command processing on selected text

struct CommandProcessor: Sendable {

    // MARK: - Constants

    private static let systemPrompt = """
        You are a text transformation assistant. You receive selected text and a voice command. \
        Apply the command to transform the text. Output ONLY the transformed text. \
        Do not add explanations, markdown formatting, or quotes around the output. \
        Preserve the original formatting style unless the command requires changing it.
        """

    // MARK: - Dependencies

    private let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    // MARK: - Processing

    func process(command: String, selectedText: String, parameters: LLMParameters = LLMParameters()) async throws -> String {
        let userPrompt = """
            Command: \(command)

            Selected text:
            \(selectedText)
            """

        let result = try await llmService.complete(
            systemPrompt: Self.systemPrompt,
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
