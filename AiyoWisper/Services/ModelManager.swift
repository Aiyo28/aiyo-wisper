import Foundation
import Hub
import WhisperKit

@MainActor @Observable
final class ModelManager {
    enum ModelCategory: String, CaseIterable {
        case standard = "Standard Whisper"
        case optimized = "Optimized (Recommended)"
    }

    struct ModelInfo: Identifiable {
        let id: String
        let name: String
        let variant: String          // Full WhisperKit variant name for download
        let size: String
        let category: ModelCategory
        let description: String
        let englishOnly: Bool
        var isDownloaded: Bool
    }

    private(set) var availableModels: [ModelInfo] = [
        // Standard Whisper models
        ModelInfo(id: "tiny", name: "Tiny", variant: "openai_whisper-tiny",
                  size: "75 MB", category: .standard,
                  description: "Fastest, least accurate", englishOnly: false, isDownloaded: false),
        ModelInfo(id: "base", name: "Base", variant: "openai_whisper-base",
                  size: "142 MB", category: .standard,
                  description: "Good balance for quick tasks", englishOnly: false, isDownloaded: false),
        ModelInfo(id: "small", name: "Small", variant: "openai_whisper-small",
                  size: "466 MB", category: .standard,
                  description: "Better accuracy, moderate speed", englishOnly: false, isDownloaded: false),
        ModelInfo(id: "medium", name: "Medium", variant: "openai_whisper-medium",
                  size: "1.5 GB", category: .standard,
                  description: "High accuracy, slower", englishOnly: false, isDownloaded: false),
        ModelInfo(id: "large-v3", name: "Large v3", variant: "openai_whisper-large-v3",
                  size: "3 GB", category: .standard,
                  description: "Best accuracy, slowest", englishOnly: false, isDownloaded: false),

        // Optimized models — use exact folder names with size suffix to avoid ambiguity
        ModelInfo(id: "large-v3-turbo", name: "Large v3 Turbo", variant: "openai_whisper-large-v3_turbo_954MB",
                  size: "954 MB", category: .optimized,
                  description: "Near large-v3 accuracy, 6x faster, 99+ languages", englishOnly: false, isDownloaded: false),
        ModelInfo(id: "distil-large-v3", name: "Distil Large v3", variant: "distil-whisper_distil-large-v3_594MB",
                  size: "594 MB", category: .optimized,
                  description: "Near large-v3 accuracy, 5-6x faster, English only", englishOnly: true, isDownloaded: false),
    ]

    private(set) var selectedModelId: String = "tiny"
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

    func models(for category: ModelCategory) -> [ModelInfo] {
        availableModels.filter { $0.category == category }
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
