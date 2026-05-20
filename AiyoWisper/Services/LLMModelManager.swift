import Foundation
import LLM

@MainActor
@Observable
final class LLMModelManager {
    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadError: String?
    private(set) var isModelDownloaded: Bool
    private(set) var lastValidationError: String?

    private var downloadTask: Task<Void, Never>?

    init() {
        isModelDownloaded = Self.validateExistingFile()
    }

    var modelPath: String? {
        guard isModelDownloaded else { return nil }
        return Constants.LLM.defaultModelPath.path
    }

    func download() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        // Always clear any prior (possibly partial) file before starting a fresh download.
        deleteFileIfPresent()

        downloadTask = Task {
            do {
                let dir = Constants.LLM.llmModelsDirectory
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let hfModel = HuggingFaceModel(
                    Constants.LLM.defaultModelRepo,
                    .Q4_K_M,
                    template: .chatML(Constants.LLM.cleanupSystemPrompt)
                )

                _ = try await hfModel.download(to: dir, as: Constants.LLM.defaultModelFile) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress
                    }
                }

                // Validate the result. If HF returned partial bytes or a wrong file, treat as failure.
                guard Self.validateExistingFile() else {
                    deleteFileIfPresent()
                    throw LLMError.modelCorrupted
                }

                isModelDownloaded = true
                isDownloading = false
                downloadProgress = 1.0
            } catch is CancellationError {
                deleteFileIfPresent()
                isModelDownloaded = false
                isDownloading = false
                downloadProgress = 0
            } catch {
                deleteFileIfPresent()
                isModelDownloaded = false
                downloadError = error.localizedDescription
                isDownloading = false
                downloadProgress = 0
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        deleteFileIfPresent()
        isModelDownloaded = false
    }

    func deleteModel() {
        deleteFileIfPresent()
        isModelDownloaded = false
    }

    /// Called when a load failure is detected at runtime — file passes existence/size check
    /// but llama.cpp refuses to load it. Treat as corrupted: delete and reset.
    func markCorruptAndDelete(reason: String) {
        deleteFileIfPresent()
        isModelDownloaded = false
        lastValidationError = reason
    }

    func refreshState() {
        isModelDownloaded = Self.validateExistingFile()
    }

    // MARK: - Validation

    /// Returns true only if the file at `defaultModelPath` is present, large enough,
    /// and has a GGUF magic header. Prevents partial downloads from being treated as ready.
    private static func validateExistingFile() -> Bool {
        let url = Constants.LLM.defaultModelPath
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        // Size check
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        guard size >= Constants.LLM.minimumModelFileSize else { return false }

        // Magic header check (first 4 bytes must be "GGUF")
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return false }
        return Array(header) == Constants.LLM.ggufMagic
    }

    private func deleteFileIfPresent() {
        let path = Constants.LLM.defaultModelPath
        if FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(at: path)
        }
    }
}
