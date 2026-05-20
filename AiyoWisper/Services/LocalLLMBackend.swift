import Foundation
import LocalLLMClient
import LocalLLMClientLlama

actor LocalLLMBackend {
    private var session: LLMSession?
    private var loadFailed = false
    private let downloadModel: LLMSession.DownloadModel
    private let modelURL: URL

    init(downloadModel: LLMSession.DownloadModel) {
        self.downloadModel = downloadModel
        self.modelURL = downloadModel.modelPath
    }

    private func ensureLoaded() async throws -> LLMSession {
        if loadFailed { throw LLMError.modelCorrupted }
        if let session { return session }

        // Pre-flight: confirm file is still present and has GGUF magic before letting
        // llama.cpp touch it. A partial download would otherwise crash or hang the
        // process during prewarm().
        guard Self.fileLooksValid(at: modelURL) else {
            loadFailed = true
            throw LLMError.modelCorrupted
        }

        let newSession = LLMSession(model: downloadModel)
        do {
            // prewarm loads the model — surface the failure here rather than on the
            // first respond() call so we can swap to .modelCorrupted cleanly.
            try await newSession.prewarm()
        } catch {
            loadFailed = true
            throw LLMError.modelCorrupted
        }
        self.session = newSession
        return newSession
    }

    func unload() {
        session = nil
    }

    private static func fileLooksValid(at url: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        guard size >= Constants.LLM.minimumModelFileSize else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return false }
        return Array(header) == Constants.LLM.ggufMagic
    }
}

extension LocalLLMBackend: LLMBackend {
    func complete(systemPrompt: String, userPrompt: String, parameters _: LLMParameters) async throws -> String {
        let session = try await ensureLoaded()

        // System prompt is set per call (we don't keep prior turns — each cleanup
        // is independent). LocalLLMClient does not honor a per-respond temperature
        // override, so the parameter set at model creation time is what takes effect.
        session.messages = [.system(systemPrompt)]

        do {
            let output = try await session.respond(to: userPrompt)
            let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { throw LLMError.noResponseContent }
            return cleaned
        } catch LLMError.noResponseContent {
            throw LLMError.noResponseContent
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Any other failure at inference time is treated as a model fault — drop
            // the session so we don't keep using a bad one.
            self.session = nil
            loadFailed = true
            throw LLMError.modelCorrupted
        }
    }

    nonisolated func isAvailable() async -> Bool {
        Self.fileLooksValid(at: modelURL)
    }
}
