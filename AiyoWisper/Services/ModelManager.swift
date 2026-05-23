import Foundation
import WhisperKit

@MainActor @Observable
final class ModelManager {
    struct ModelInfo: Identifiable {
        let id: String
        let name: String
        let variant: String          // Full WhisperKit variant name for download
        let size: String
        let description: String
        let englishOnly: Bool
        var isDownloaded: Bool
    }

    private(set) var availableModels: [ModelInfo] = [
        ModelInfo(id: "small", name: "Small", variant: "openai_whisper-small_216MB",
                  size: "216 MB",
                  description: "Balanced multilingual option. Use Turbo for higher accuracy.",
                  englishOnly: false, isDownloaded: false),
        ModelInfo(id: "large-v3-turbo", name: "Turbo", variant: "openai_whisper-large-v3-v20240930_turbo_632MB",
                  size: "632 MB",
                  description: "Highest accuracy. All languages. Recommended for most users.",
                  englishOnly: false, isDownloaded: false),
        ModelInfo(id: "distil-large-v3", name: "English Turbo", variant: "distil-whisper_distil-large-v3_turbo_600MB",
                  size: "600 MB",
                  description: "Fastest and most accurate for English only.",
                  englishOnly: true, isDownloaded: false),
        ModelInfo(id: "tiny", name: "Lightweight", variant: "openai_whisper-tiny",
                  size: "77 MB",
                  description: "Smallest download. Good for quick notes. All languages.",
                  englishOnly: false, isDownloaded: false),
    ]

    private(set) var selectedModelId: String = "small"
    private(set) var downloadProgress: Double = 0
    var isDownloading = false
    var currentDownloadModel: String?

    private let fileManager = FileManager.default
    private var downloadTask: Task<Void, Error>?

    var modelsDirectory: URL {
        Constants.Models.modelsDirectory
    }

    init() {
        refreshDownloadedModels()
    }

    func refreshDownloadedModels() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for i in availableModels.indices {
            let variant = availableModels[i].variant
            availableModels[i].isDownloaded = contents.contains { item in
                item.hasDirectoryPath && item.lastPathComponent.hasPrefix(variant)
            }
        }
    }

    func download(modelId: String) async throws {
        guard let model = availableModels.first(where: { $0.id == modelId }) else { return }

        // Cancel any in-flight download before starting a new one.
        downloadTask?.cancel()

        isDownloading = true
        downloadProgress = 0
        currentDownloadModel = modelId

        let task = Task<Void, Error> { [weak self] in
            guard let self else { return }
            try Task.checkCancellation()
            try self.fileManager.createDirectory(at: self.modelsDirectory, withIntermediateDirectories: true)

            let downloadedURL = try await WhisperKit.download(
                variant: model.variant,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            )
            try Task.checkCancellation()

            let destination = self.modelsDirectory.appendingPathComponent(downloadedURL.lastPathComponent)
            if downloadedURL != destination && !self.fileManager.fileExists(atPath: destination.path) {
                try self.fileManager.moveItem(at: downloadedURL, to: destination)
            }

            self.downloadProgress = 1.0
            self.refreshDownloadedModels()
        }
        downloadTask = task
        defer {
            isDownloading = false
            currentDownloadModel = nil
            downloadTask = nil
        }
        try await task.value
    }

    /// Cancels an in-flight model download. Safe to call when nothing is downloading.
    /// Partial files left behind by WhisperKit's downloader are not cleaned up here —
    /// re-running download() will resume or restart depending on HF's snapshot logic.
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        currentDownloadModel = nil
        downloadProgress = 0
    }

    func deleteModel(_ modelId: String) throws {
        guard let model = availableModels.first(where: { $0.id == modelId }) else { return }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for item in contents where item.hasDirectoryPath {
            if item.lastPathComponent.hasPrefix(model.variant) {
                try fileManager.removeItem(at: item)
            }
        }
        refreshDownloadedModels()
    }

    func selectModel(_ id: String) {
        selectedModelId = id
    }

    func modelPath(for modelId: String) -> URL? {
        guard let model = availableModels.first(where: { $0.id == modelId }) else { return nil }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return nil }

        return contents.first { item in
            item.hasDirectoryPath && item.lastPathComponent.hasPrefix(model.variant)
        }
    }

    func isModelDownloaded(_ modelId: String) -> Bool {
        availableModels.first { $0.id == modelId }?.isDownloaded ?? false
    }
}
