import AVFAudio
import Foundation
import NaturalLanguage
import Speech

/// On-device speech-to-text via Apple's `SpeechAnalyzer` / `SpeechTranscriber`
/// (macOS 26+). The default backend as of v1.2.0.
///
/// Why this replaces WhisperKit as the default:
///   - **No app-managed download.** The locale model is system-provided and shared
///     (`AssetInventory`), not a 600 MB per-app blob living in Application Support.
///   - **No language bleed within a pass.** A transcriber is pinned to one `Locale`.
///   - **Lower latency + Neural Engine.** Apple's pipeline is tuned for the hardware.
///
/// **Language modes.** Prepared with one locale → pinned. Prepared with several →
/// *auto-detect*: every clip is transcribed once per candidate locale and the pass with
/// the highest average acoustic confidence wins. Apple's API has no spoken-language
/// detector, and EN/RU differ only by script (so the output script can't tell us which
/// language was *spoken*) — confidence is the only honest signal, so that's what we use.
///
/// **Threading contract:** `@unchecked Sendable`, driven only from the pipeline's
/// `@MainActor` with `await`.
final class AppleSpeechEngine: TranscriptionProviding, @unchecked Sendable {
    /// Prepared locales. One element = pinned language; two+ = auto-detect across them.
    private var preparedLocales: [Locale] = []
    private var ready = false

    /// Language codes the caller requested that Apple's on-device engine doesn't offer on
    /// this OS (e.g. Russian — absent from `supportedLocales` on macOS 27 betas). Set by
    /// `prepare`; the pipeline surfaces it as a soft notice so the user knows those clips
    /// won't transcribe here and should use WhisperKit.
    private(set) var unsupportedLanguageCodes: [String] = []

    /// Upper bound on contextual-bias terms handed to the analyzer per utterance.
    private static let maxContextualStrings = 100

    var isReady: Bool { ready }

    /// Whether SpeechTranscriber can serve the given short language code on this Mac.
    static func isLocaleSupported(_ languageCode: String) async -> Bool {
        let target = Locale(identifier: Constants.Language.speechLocaleIdentifier(for: languageCode))
        let supported = await SpeechTranscriber.supportedLocales
        return supported.contains { $0.identifier(.bcp47) == target.identifier(.bcp47) }
    }

    /// Which of `candidates` Apple's on-device engine can serve on this OS, preserving
    /// order. Grows on its own as future macOS releases add locales (e.g. Russian) — no
    /// code change needed; the language pickers read this and expand automatically.
    static func supportedLanguageCodes(among candidates: [String]) async -> [String] {
        let supported = await SpeechTranscriber.supportedLocales
        return candidates.filter { code in
            let target = Locale(identifier: Constants.Language.speechLocaleIdentifier(for: code))
            return supported.contains { $0.identifier(.bcp47) == target.identifier(.bcp47) }
        }
    }

    /// Ensures the on-device model for each language code is installed and reserved.
    /// Pass one code to pin a language, or several to enable auto-detect across them.
    func prepare(languageCodes: [String]) async throws {
        ready = false
        preparedLocales = []
        unsupportedLanguageCodes = []

        let supported = await SpeechTranscriber.supportedLocales
        var locales: [Locale] = []
        var unsupported: [String] = []

        for code in languageCodes {
            let localeID = Constants.Language.speechLocaleIdentifier(for: code)
            let locale = Locale(identifier: localeID)

            // Skip languages Apple doesn't offer on this OS rather than failing the whole
            // engine — otherwise picking Auto (en + ru) would kill English too when ru is
            // absent. Only the missing language is dropped; the rest keep working.
            guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
                unsupported.append(code)
                continue
            }

            let installed = await SpeechTranscriber.installedLocales
            if !installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
                let probe = SpeechTranscriber(locale: locale, preset: .transcription)
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                    try await request.downloadAndInstall()
                }
            }

            let reserved = await AssetInventory.reservedLocales
            if !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
                _ = try await AssetInventory.reserve(locale: locale)
            }

            locales.append(locale)
        }

        unsupportedLanguageCodes = unsupported

        // Every requested language is unavailable → this engine genuinely can't serve the
        // request; surface it so the pipeline can route the user to WhisperKit.
        guard !locales.isEmpty else {
            throw TranscriptionError.localeUnsupported(
                languageCodes.map { Constants.Language.speechLocaleIdentifier(for: $0) }.joined(separator: ", ")
            )
        }

        preparedLocales = locales
        ready = true
        Log.pipeline.info("AppleSpeechEngine ready: \(locales.map { $0.identifier(.bcp47) }.joined(separator: ","), privacy: .public); unsupported: \(unsupported.joined(separator: ","), privacy: .public)")
    }

    func transcribe(samples: [Float], language: String?, vocabulary: [String]) async throws -> TranscriptionResult {
        guard ready, !preparedLocales.isEmpty else {
            throw TranscriptionError.modelNotLoaded
        }
        guard !samples.isEmpty else {
            return TranscriptionResult(text: "", language: preparedLocales[0].identifier(.bcp47))
        }

        let url = try Self.writeTempWav(samples)
        defer { try? FileManager.default.removeItem(at: url) }

        // Pinned single language — one pass, no scoring.
        if preparedLocales.count == 1 {
            let locale = preparedLocales[0]
            let pass = try await transcribeOnce(locale: locale, url: url, vocabulary: vocabulary)
            return TranscriptionResult(text: pass.text, language: locale.identifier(.bcp47))
        }

        // Auto-detect — transcribe with every candidate locale, keep the best.
        var candidates: [Pass] = []
        for locale in preparedLocales {
            let pass = try await transcribeOnce(locale: locale, url: url, vocabulary: vocabulary)
            if !pass.text.isEmpty { candidates.append(pass) }
        }
        guard let winner = Self.pickBest(candidates) else {
            return TranscriptionResult(text: "", language: preparedLocales[0].identifier(.bcp47))
        }
        Log.transcribe.info("AppleSpeech auto → \(winner.locale.identifier(.bcp47), privacy: .public) (conf \(String(format: "%.2f", winner.avgConfidence), privacy: .public), n=\(candidates.count, privacy: .public))")
        return TranscriptionResult(text: winner.text, language: winner.locale.identifier(.bcp47))
    }

    func unload() {
        ready = false
        preparedLocales = []
    }

    // MARK: - One transcription pass

    private struct Pass {
        let locale: Locale
        let text: String
        let avgConfidence: Double   // mean per-token acoustic confidence; -1 if unavailable
    }

    private func transcribeOnce(locale: Locale, url: URL, vocabulary: [String]) async throws -> Pass {
        let audioFile = try AVAudioFile(forReading: url)
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.transcriptionConfidence]
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        if !vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings = [.general: Array(vocabulary.prefix(Self.maxContextualStrings))]
            try await analyzer.setContext(context)
        }

        let results = transcriber.results
        let collector = Task { () throws -> (text: String, confSum: Double, confCount: Int) in
            var text = ""
            var confSum = 0.0
            var confCount = 0
            for try await result in results where result.isFinal {
                let attributed = result.text
                text += String(attributed.characters) + " "
                for run in attributed.runs {
                    if let confidence = run.transcriptionConfidence {
                        confSum += confidence
                        confCount += 1
                    }
                }
            }
            return (text, confSum, confCount)
        }

        if let last = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let (raw, confSum, confCount) = try await collector.value
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let avg = confCount > 0 ? confSum / Double(confCount) : -1
        return Pass(locale: locale, text: text, avgConfidence: avg)
    }

    /// Picks the winning pass. Primary signal: mean acoustic confidence (the correct
    /// language forces fewer foreign phonemes → higher confidence). If confidence didn't
    /// populate on any pass, fall back to NaturalLanguage: keep only passes whose detected
    /// dominant language matches their own locale, and take the most confident of those.
    private static func pickBest(_ passes: [Pass]) -> Pass? {
        guard !passes.isEmpty else { return nil }

        if passes.contains(where: { $0.avgConfidence >= 0 }) {
            return passes.max { $0.avgConfidence < $1.avgConfidence }
        }

        // Confidence unavailable — use language-identification as a fallback.
        let scored = passes.map { pass -> (Pass, Double) in (pass, nlMatchScore(text: pass.text, locale: pass.locale)) }
        if let best = scored.filter({ $0.1 > 0 }).max(by: { $0.1 < $1.1 }) {
            return best.0
        }
        // Nothing matched — return the longest transcript as a last resort.
        return passes.max { $0.text.count < $1.text.count }
    }

    /// Confidence that `text` is actually in `locale`'s language, per NaturalLanguage.
    /// Zero unless the detected dominant language matches the locale (so a wrong-language
    /// pass's phonetic gibberish doesn't score for its own script).
    private static func nlMatchScore(text: String, locale: Locale) -> Double {
        guard !text.isEmpty else { return 0 }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage,
              let localeLang = locale.language.languageCode?.identifier,
              dominant.rawValue.hasPrefix(localeLang) else { return 0 }
        return recognizer.languageHypotheses(withMaximum: 3)[dominant] ?? 0.5
    }

    // MARK: - Audio staging

    /// Writes 16 kHz mono Float32 samples to a temporary WAV. `SpeechAnalyzer.analyzeSequence(from:)`
    /// accepts any `AVAudioFile` and converts internally, so no pre-conversion is needed.
    private static func writeTempWav(_ samples: [Float]) throws -> URL {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.Audio.sampleRate,
            channels: 1,
            interleaved: false
        )!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aiyo-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw TranscriptionError.audioFormatUnavailable
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
        return url
    }
}
