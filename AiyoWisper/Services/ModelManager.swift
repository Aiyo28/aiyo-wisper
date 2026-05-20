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
                  description: "Best balance of speed and quality. All languages.",
                  englishOnly: false, isDownloaded: false),
        ModelInfo(id: "large-v3-turbo", name: "Turbo", variant: "openai_whisper-large-v3-v20240930_turbo_632MB",
                  size: "632 MB",
                  description: "Highest accuracy. All languages. Larger download.",
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

        isDownloading = true
        downloadProgress = 0
        currentDownloadModel = modelId

        defer {
            isDownloading = false
            currentDownloadModel = nil
        }

        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // WhisperKit 1.0+ provides its own vendored HuggingFace downloader (HubApiWrapper),
        // dropping the swift-transformers dep that conflicted with LocalLLMClient.
        let downloadedURL = try await WhisperKit.download(
            variant: model.variant,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress.fractionCompleted
                }
            }
        )

        // Move model into the app's Models directory if not already there
        let destination = modelsDirectory.appendingPathComponent(downloadedURL.lastPathComponent)
        if downloadedURL != destination && !fileManager.fileExists(atPath: destination.path) {
            try fileManager.moveItem(at: downloadedURL, to: destination)
        }

        downloadProgress = 1.0
        refreshDownloadedModels()
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
