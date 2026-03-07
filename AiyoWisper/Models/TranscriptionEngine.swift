import Foundation
import WhisperKit

/// Thread safety: All mutable state access is guarded by MainActor isolation.
/// The class is @unchecked Sendable only because WhisperKit's async APIs
/// require crossing isolation boundaries. Callers must access from @MainActor.
@MainActor
final class TranscriptionEngine {
    // nonisolated(unsafe): WhisperKit must cross isolation to call its nonisolated async API.
    // Safety: all reads/writes are serialized on MainActor.
    nonisolated(unsafe) private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false

    func loadModel(path: String) async throws {
        let config = WhisperKitConfig(
            modelFolder: path,
            load: true,
            download: false
        )
        whisperKit = try await WhisperKit(config)
        isModelLoaded = true
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        nonisolated(unsafe) let kit = whisperKit
        let results = try await kit.transcribe(audioArray: audioSamples)

        let text = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No transcription model is loaded"
        }
    }
}
