import Foundation
import LocalLLMClient
import LocalLLMClientLlama

@MainActor
@Observable
final class LLMModelManager {
    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadError: String?
    private(set) var isModelDownloaded: Bool
    private(set) var lastValidationError: String?

    private var downloadTask: Task<Void, Never>?

    /// Single source of truth for the model definition. LocalLLMClient handles file
    /// storage internally — modelPath property tells us where it lives.
    let downloadModel: LLMSession.DownloadModel

    init() {
        let model = LLMSession.DownloadModel.llama(
            id: Constants.LLM.defaultModelRepo,
            model: Constants.LLM.defaultModelFile,
            parameter: .init(temperature: 0.3, topP: 0.9)
        )
        self.downloadModel = model
        // Combine the package's own check with our integrity check so partial files
        // don't get treated as ready.
        self.isModelDownloaded = model.isDownloaded && Self.fileLooksValid(at: model.modelPath)
    }

    var modelPath: URL? {
        guard isModelDownloaded else { return nil }
        return downloadModel.modelPath
    }

    func download() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        // Always purge any prior partial file before starting fresh.
        deleteFileIfPresent()

        downloadTask = Task {
            do {
                try await downloadModel.downloadModel { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress
                    }
                }

                guard Self.fileLooksValid(at: downloadModel.modelPath) else {
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

    /// Runtime corruption signal from the backend — file passed pre-flight but llama.cpp
    /// refused to load it. Treat the same as a partial download.
    func markCorruptAndDelete(reason: String) {
        deleteFileIfPresent()
        isModelDownloaded = false
        lastValidationError = reason
    }

    func refreshState() {
        isModelDownloaded = downloadModel.isDownloaded && Self.fileLooksValid(at: downloadModel.modelPath)
    }

    // MARK: - Validation

    /// Defense in depth on top of LocalLLMClient's own download integrity: confirm the
    /// file is large enough and starts with GGUF magic bytes before we hand it to
    /// llama.cpp.
    private static func fileLooksValid(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        guard size >= Constants.LLM.minimumModelFileSize else { return false }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return false }
        return Array(header) == Constants.LLM.ggufMagic
    }

    private func deleteFileIfPresent() {
        let url = downloadModel.modelPath
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
