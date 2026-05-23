import Foundation
import Testing
@testable import AiyoWisper

/// Regression guards for `SmartFormatter` regex passes — specifically the
/// course-correction tightening that prevents casual occurrences of marker words
/// ("sorry", "I mean", etc.) from silently nuking long dictations.
@Suite("SmartFormatter regex passes")
struct SmartFormatterRegexTests {

    @Test("casual 'sorry' mid-sentence no longer strips entire prefix")
    func casualMarkerDoesNotStripWholeSentence() {
        let formatter = SmartFormatter()
        // Whisper output is run-on, no periods. "Sorry" appears casually.
        let input = "I want to say sorry for taking so long with the report"

        let output = formatter.format(input, modelId: "tiny", minimalMode: true)

        // Expect the dictation to survive — at minimum the second half should remain.
        #expect(output.contains("taking so long"))
        #expect(!output.isEmpty)
    }

    @Test("comma-anchored course correction removes the marker word")
    func commaAnchoredCorrectionRemovesMarker() {
        let formatter = SmartFormatter()
        // Deliberate trade-off: we no longer strip the noun phrase before the comma
        // (safe stripping requires sentence boundaries Whisper doesn't reliably emit).
        // The marker word itself is still removed.
        let input = "let's go to the park, sorry, the beach"

        let output = formatter.format(input, modelId: "tiny", minimalMode: true)

        #expect(!output.lowercased().contains("sorry"))
        #expect(output.lowercased().contains("beach"))
        #expect(output.count > 10)
    }

    @Test("run-on Whisper output is never reduced to empty by regex passes")
    func runOnTranscriptSurvivesRegexPasses() {
        let formatter = SmartFormatter()
        let input = "okay so I wanted to talk about the project status I mean basically we are on track for the deadline you know and sorry for the long update but there are a few things to mention"

        let output = formatter.format(input, modelId: "tiny", minimalMode: true)

        #expect(output.lowercased().contains("track for the deadline"))
        #expect(output.lowercased().contains("things to mention"))
        #expect(output.count > input.count / 2)
    }
}

/// Defense-in-depth tests for the special-token strip that backstops WhisperKit's
/// detokenizer leaking `<|startoftranscript|>`, `<|de|>`, `<|0.00|>` etc. into the
/// final transcript text. Observed on 2026-05-22 with large-v3-turbo on short
/// English clips that Whisper misidentified as German.
@Suite("TranscriptionEngine special-token strip")
struct SpecialTokenStripTests {

    @Test("strips startoftranscript / language / timestamp / endoftext tokens")
    func stripsAllStructuralTokens() {
        let leaked = "Hello, hello, hello is this working now? <|startoftranscript|><|de|><|transcribe|><|0.00|><|endoftext|>"
        let cleaned = TranscriptionEngine.stripSpecialTokens(leaked)

        #expect(cleaned == "Hello, hello, hello is this working now?")
    }

    @Test("strips repeated structural-only output to empty")
    func stripsPureLeakToEmpty() {
        let leaked = "<|startoftranscript|><|de|><|transcribe|><|0.00|><|endoftext|> <|startoftranscript|><|de|><|transcribe|><|0.00|><|endoftext|>"
        let cleaned = TranscriptionEngine.stripSpecialTokens(leaked)

        #expect(cleaned.isEmpty)
    }

    @Test("preserves normal text without any tokens")
    func preservesNormalText() {
        let text = "Just normal speech transcription with no leakage."
        let cleaned = TranscriptionEngine.stripSpecialTokens(text)

        #expect(cleaned == text)
    }

    @Test("collapses double spaces left by token removal")
    func collapsesDoubleSpaces() {
        let leaked = "Word one <|en|> word two"
        let cleaned = TranscriptionEngine.stripSpecialTokens(leaked)

        #expect(cleaned == "Word one word two")
    }
}
