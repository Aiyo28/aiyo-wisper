import Foundation
import WhisperKit

struct TranscriptionResult {
    let text: String
    let language: String
}

final class TranscriptionEngine: @unchecked Sendable {
    private var whisperKit: WhisperKit?
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

    func transcribe(audioSamples: [Float], language: String?, vocabularyWords: [String] = []) async throws -> TranscriptionResult {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        var promptTokens: [Int]?
        if !vocabularyWords.isEmpty, let tokenizer = whisperKit.tokenizer {
            promptTokens = vocabularyWords.flatMap { tokenizer.encode(text: $0) }
        }

        let options = DecodingOptions(
            language: language,
            detectLanguage: language == nil ? true : nil,
            promptTokens: promptTokens
        )

        let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)

        let text = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let detectedLanguage = results.first?.language ?? language ?? "en"

        return TranscriptionResult(text: text, language: detectedLanguage)
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
