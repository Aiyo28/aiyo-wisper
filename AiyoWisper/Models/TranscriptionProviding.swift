import Foundation

/// Result of a single transcription pass, independent of which backend produced it.
struct TranscriptionResult {
    let text: String
    let language: String
    /// Number of characters removed by a backend's special-token strip pass. When this
    /// is non-zero but `text` is empty, the backend returned only structural tokens with
    /// no real content — distinct from genuine silence. The pipeline uses this to surface
    /// a more accurate diagnostic. Apple's SpeechTranscriber never leaks tokens, so its
    /// engine always reports `0`.
    let strippedCount: Int

    init(text: String, language: String, strippedCount: Int = 0) {
        self.text = text
        self.language = language
        self.strippedCount = strippedCount
    }
}

/// A speech-to-text backend. Both `TranscriptionEngine` (WhisperKit) and
/// `AppleSpeechEngine` (SpeechAnalyzer) conform, so the pipeline can swap engines
/// behind a single call site.
///
/// **Threading contract:** conformers are `@unchecked Sendable`; the pipeline drives
/// them exclusively from `@MainActor` with `await`, so their internal mutable state is
/// naturally serialized. Do not touch a conformer from more than one isolation domain.
protocol TranscriptionProviding: AnyObject, Sendable {
    /// True once the engine can service `transcribe(...)` without further setup.
    var isReady: Bool { get }

    /// Transcribe 16 kHz mono Float32 samples. `language` is a short code ("en", "ru")
    /// or nil for the engine's default/auto behavior. `vocabulary` is a best-effort hint;
    /// engines that can't honor it ignore it (the pipeline still applies dictionary
    /// corrections afterward).
    func transcribe(samples: [Float], language: String?, vocabulary: [String]) async throws -> TranscriptionResult

    /// Release any loaded model/session state.
    func unload()
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case audioFormatUnavailable
    case localeUnsupported(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No transcription model is loaded"
        case .audioFormatUnavailable:
            return "Could not determine a compatible audio format for on-device transcription"
        case .localeUnsupported(let id):
            return "On-device speech recognition isn't available for \(id) on this Mac"
        }
    }
}
