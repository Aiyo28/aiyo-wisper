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
            maxTokenCount: 256
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
        llm.template = .chatML(systemPrompt)

        let output = await llm.getCompletion(from: userPrompt)
        llm.history = []
        llm.reset()

        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw LLMError.noResponseContent
        }
        return cleaned
    }

    func isAvailable() async -> Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }
}
