import Foundation

// MARK: - LLM Backend Protocol

protocol LLMBackend: Sendable {
    func complete(systemPrompt: String, userPrompt: String, parameters: LLMParameters) async throws -> String
    func isAvailable() async -> Bool
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case modelNotLoaded
    case modelCorrupted
    case inferenceTimeout
    case noResponseContent
    case inferenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "LLM model not loaded — download it in Settings → Formatting"
        case .modelCorrupted:
            "LLM model file is corrupted or incomplete — re-download in Settings → Formatting"
        case .inferenceTimeout:
            "LLM inference timed out"
        case .noResponseContent:
            "LLM response contained no content"
        case .inferenceFailed(let error):
            "LLM inference failed: \(error.localizedDescription)"
        }
    }
}
