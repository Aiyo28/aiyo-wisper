import Foundation
import Hub
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
        ModelInfo(id: "large-v3-turbo", name: "Turbo", variant: "openai_whisper-large-v3_turbo_954MB",
                  size: "954 MB",
                  description: "Best all-round — 99+ languages, near large-v3 accuracy at 6x speed",
                  englishOnly: false, isDownloaded: false),
        ModelInfo(id: "distil-large-v3", name: "English Turbo", variant: "distil-whisper_distil-large-v3_594MB",
                  size: "594 MB",
                  description: "Fastest for English — max accuracy, optimized for English only",
                  englishOnly: true, isDownloaded: false),
        ModelInfo(id: "tiny", name: "Fast", variant: "openai_whisper-tiny",
                  size: "66 MB",
                  description: "Lightweight — for low bandwidth or future iPhone use. Multilingual.",
                  englishOnly: false, isDownloaded: false),
    ]

    private(set) var selectedModelId: String = "large-v3-turbo"
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

        let progressCallback: @Sendable (Progress) -> Void = { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress.fractionCompleted
            }
        }

        // Use HubApi directly with exact variant glob for reliable downloads
        let hubApi = HubApi()
        let repo = Hub.Repo(id: "argmaxinc/whisperkit-coreml", type: .models)
        let modelFolder = try await hubApi.snapshot(
            from: repo,
            matching: ["\(model.variant)/*"],
            progressHandler: progressCallback
        )
        let downloadedURL = modelFolder.appendingPathComponent(model.variant)

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
