import Foundation
import LLM

@MainActor
@Observable
final class LLMModelManager {
    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadError: String?
    private(set) var isModelDownloaded: Bool

    private var downloadTask: Task<Void, Never>?

    init() {
        isModelDownloaded = FileManager.default.fileExists(atPath: Constants.LLM.defaultModelPath.path)
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

        downloadTask = Task {
            do {
                let dir = Constants.LLM.llmModelsDirectory
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let hfModel = HuggingFaceModel(
                    Constants.LLM.defaultModelRepo,
                    .Q4_K_M,
                    template: .chatML(Constants.LLM.cleanupSystemPrompt)
                )

                let _ = try await hfModel.download(to: dir, as: Constants.LLM.defaultModelFile) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress
                    }
                }

                isModelDownloaded = true
                isDownloading = false
                downloadProgress = 1.0
            } catch is CancellationError {
                isDownloading = false
                downloadProgress = 0
            } catch {
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
    }

    func deleteModel() {
        let path = Constants.LLM.defaultModelPath
        try? FileManager.default.removeItem(at: path)
        isModelDownloaded = false
    }

    func refreshState() {
        isModelDownloaded = FileManager.default.fileExists(atPath: Constants.LLM.defaultModelPath.path)
    }
}
