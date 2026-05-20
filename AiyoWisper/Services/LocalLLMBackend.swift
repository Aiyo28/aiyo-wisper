import Foundation
import LLM

final class LocalLLMBackend: @unchecked Sendable {
    private var model: LLM?
    private var loadFailed = false
    private let modelPath: String
    private let lock = NSLock()

    init(modelPath: String) {
        self.modelPath = modelPath
    }

    private func ensureLoaded() throws -> LLM {
        lock.lock()
        defer { lock.unlock() }
        if loadFailed {
            throw LLMError.modelCorrupted
        }
        if let model { return model }

        // Pre-flight: confirm file is still present and has GGUF magic before letting
        // llama.cpp touch it. A partial download can crash or hang the process.
        guard Self.fileLooksValid(at: modelPath) else {
            loadFailed = true
            throw LLMError.modelCorrupted
        }

        guard let loaded = LLM(
            from: modelPath,
            topP: 0.9,
            temp: 0.3,
            repeatPenalty: 1.1,
            maxTokenCount: 256
        ) else {
            loadFailed = true
            throw LLMError.modelCorrupted
        }
        self.model = loaded
        return loaded
    }

    func unload() {
        lock.lock()
        model = nil
        lock.unlock()
    }

    private static func fileLooksValid(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int64) ?? 0
        guard size >= Constants.LLM.minimumModelFileSize else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return false }
        return Array(header) == Constants.LLM.ggufMagic
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
        Self.fileLooksValid(at: modelPath)
    }
}
