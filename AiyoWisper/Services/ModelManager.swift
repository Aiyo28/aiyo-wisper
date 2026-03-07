import Foundation
import WhisperKit

@MainActor @Observable
final class ModelManager {
    struct ModelInfo: Identifiable {
        let id: String
        let name: String
        let size: String
        var isDownloaded: Bool
    }

    private(set) var availableModels: [ModelInfo] = [
        ModelInfo(id: "tiny", name: "Tiny", size: "75 MB", isDownloaded: false),
        ModelInfo(id: "base", name: "Base", size: "142 MB", isDownloaded: false),
        ModelInfo(id: "small", name: "Small", size: "466 MB", isDownloaded: false),
        ModelInfo(id: "medium", name: "Medium", size: "1.5 GB", isDownloaded: false),
        ModelInfo(id: "large-v3", name: "Large", size: "3 GB", isDownloaded: false),
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

    func refreshDownloadedModels() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for i in availableModels.indices {
            let modelId = availableModels[i].id
            availableModels[i].isDownloaded = contents.contains { item in
                item.hasDirectoryPath && item.lastPathComponent.localizedCaseInsensitiveContains(modelId)
            }
        }
    }

    func download(modelId: String) async throws {
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
        _ = try await WhisperKit.download(
            variant: "openai_whisper-\(modelId)",
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: progressCallback
        )

        downloadProgress = 1.0
        refreshDownloadedModels()
    }

    func deleteModel(_ modelId: String) throws {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for item in contents where item.hasDirectoryPath {
            if item.lastPathComponent.localizedCaseInsensitiveContains(modelId) {
                try fileManager.removeItem(at: item)
            }
        }
        refreshDownloadedModels()
    }

    func selectModel(_ id: String) {
        selectedModelId = id
    }

    func modelPath(for modelId: String) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory, includingPropertiesForKeys: nil
        ) else { return nil }

        return contents.first { item in
            item.hasDirectoryPath && item.lastPathComponent.localizedCaseInsensitiveContains(modelId)
        }
    }

    func isModelDownloaded(_ modelId: String) -> Bool {
        availableModels.first { $0.id == modelId }?.isDownloaded ?? false
    }
}
