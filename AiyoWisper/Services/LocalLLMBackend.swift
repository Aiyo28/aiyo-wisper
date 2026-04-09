import Foundation
import LLM

final class LocalLLMBackend: @unchecked Sendable {
    private var model: LLM?
    private let modelPath: String
    private let lock = NSLock()

    init(modelPath: String) {
        self.modelPath = modelPath
    }

    private func ensureLoaded() throws -> LLM {
        lock.lock()
        defer { lock.unlock() }
        if let model { return model }
        guard let loaded = LLM(
            from: modelPath,
            topP: 0.9,
            temp: 0.3,
            repeatPenalty: 1.1,
            maxTokenCount: 1024
        ) else {
            throw LLMError.modelNotLoaded
        }
        self.model = loaded
        return loaded
    }

    func unload() {
        lock.lock()
        model = nil
        lock.unlock()
    }
}

extension LocalLLMBackend: LLMBackend {
    func complete(systemPrompt: String, userPrompt: String, parameters: LLMParameters) async throws -> String {
        let llm = try ensureLoaded()

        llm.temp = Float(parameters.temperature)
        llm.historyLimit = 0

        if llm.template == nil {
            llm.template = .chatML(systemPrompt)
        }

        let output = await llm.getCompletion(from: userPrompt)
        llm.history = []

        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw LLMError.noResponseContent
        }
        return stripWrappingQuotes(cleaned)
    }

    func isAvailable() async -> Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    private func stripWrappingQuotes(_ text: String) -> String {
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("`", "`")]
        for (open, close) in pairs {
            if text.first == open, text.last == close, text.count >= 2 {
                return String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}
