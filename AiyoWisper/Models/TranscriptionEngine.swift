import Foundation
import WhisperKit

struct TranscriptionResult {
    let text: String
    let language: String
    /// Number of characters removed by the special-token strip pass. When this is
    /// non-zero but `text` is empty, Whisper returned only structural tokens
    /// (`<|startoftranscript|><|XX|>...<|endoftext|>`) with no real content —
    /// distinct from genuine silence. The pipeline uses this to surface a more
    /// accurate error message.
    let strippedCount: Int
}

/// Wraps WhisperKit for CoreML-backed transcription.
///
/// **Threading contract:** `@unchecked Sendable` because WhisperKit's own types aren't
/// `Sendable` under Swift 6 strict concurrency. The pipeline calls `loadModel` and
/// `transcribe` exclusively from `@MainActor` with `await`, so mutation of
/// `whisperKit` and `isModelLoaded` is naturally serialized. If a future caller
/// crosses that boundary (e.g. background transcription), convert this to an `actor`.
final class TranscriptionEngine: @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false

    /// Whisper's structural / control tokens. WhisperKit's tokenizer should strip these
    /// when detokenizing segments, but in v1.0 some decoder fallback paths return the
    /// raw special tokens in `segment.text` — they leaked verbatim to the user's
    /// cursor as `<|startoftranscript|><|de|><|transcribe|><|0.00|><|endoftext|>`.
    /// Defense-in-depth strip in `transcribe(...)` below.
    private static let specialTokenPattern = "<\\|[^|]+\\|>"

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

        // Language selection:
        //   - Forced language: pass `language`, leave `detectLanguage` nil.
        //   - Auto-detect: `language: nil` AND `detectLanguage: true`.
        //
        // Whisper's language head is unreliable on short clips (<2-3s) and was
        // returning German ("<|de|>") for English speech, causing the decoder to
        // emit just the structural tokens and no usable text. For short audio we
        // bypass auto-detect and force `preferredLanguage`. Long-form keeps
        // auto-detect because there's enough audio for the language head to settle.
        let durationSec = Double(audioSamples.count) / Constants.Audio.sampleRate
        let needsChunking = durationSec > 25
        let effectiveLanguage: String? = {
            if let language { return language }                 // forced by user
            if durationSec < 3.0 { return "en" }                // short-clip safety net
            return nil                                          // long-clip: let auto-detect run
        }()
        let useAutoDetect = effectiveLanguage == nil
        // Decoding thresholds — product principle: "some transcript is better than
        // breaking the flow of dictation."
        //
        // WhisperKit has FOUR independent gates that can discard decoded text. The
        // 2026-05-23 logs showed the two log-prob gates firing on every legitimate
        // sentence ("Fallback #1 (firstTokenLogProbThreshold)" → cascade through
        // temperatures → final empty result). The cascade is supposed to recover by
        // re-decoding at higher temperatures, but if the hot-temperature output also
        // fails the thresholds, the result is dropped entirely.
        //
        // Policy: disable every filtering gate EXCEPT compression-ratio. That single
        // gate catches "Hello, hello, hello" repetition garbage at default 2.4; the
        // others were rejecting real speech. If hallucinations start showing up,
        // tighten compressionRatioThreshold to 2.0 BEFORE re-enabling log-prob gates.
        let options = DecodingOptions(
            language: effectiveLanguage,
            detectLanguage: useAutoDetect ? true : nil,
            promptTokens: promptTokens,
            compressionRatioThreshold: 2.4,
            logProbThreshold: nil,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: nil,
            chunkingStrategy: needsChunking ? .vad : .none
        )

        let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)

        // Pull text from each result. WhisperKit's tokenizer normally strips special
        // tokens from `result.text` for us, but on temperature-fallback paths the
        // raw token stream can leak through segments. Concatenate top-level text;
        // for the chunked path, fall back to segments when top-level is empty (that
        // chunker leaves chunk.text unset). Skip the segment fallback in the
        // single-window path — there it only ever surfaces leaked structural tokens
        // that the strip pass then has to clean up anyway.
        let perResultText: [String] = results.map { result in
            let topLevel = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !topLevel.isEmpty || !needsChunking { return topLevel }
            return result.segments
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let rawText = perResultText
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let text = Self.stripSpecialTokens(rawText)
        let strippedCount = rawText.count - text.count
        let detectedLanguage = results.first?.language ?? language ?? "en"

        // Metadata-only logging. Model name + language are non-sensitive, mark
        // `.public` so they show in Console.app; never log the transcribed text.
        Log.transcribe.info("\(String(format: "%.1f", durationSec), privacy: .public)s audio (chunked=\(needsChunking, privacy: .public)) → \(results.count, privacy: .public) result(s), \(text.count, privacy: .public) chars (stripped=\(strippedCount, privacy: .public)), lang=\(detectedLanguage, privacy: .public)")

        return TranscriptionResult(text: text, language: detectedLanguage, strippedCount: strippedCount)
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
    }

    /// Removes any leaked Whisper special tokens (`<|startoftranscript|>`, `<|en|>`,
    /// `<|0.00|>`, `<|endoftext|>`, etc.) from the final text. WhisperKit's detokenizer
    /// should already do this for normal paths; this is a backstop for fallback
    /// decoder paths that leak them through.
    static func stripSpecialTokens(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: specialTokenPattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
