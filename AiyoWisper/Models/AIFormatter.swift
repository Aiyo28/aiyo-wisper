import Foundation
import FoundationModels

/// Cleans up raw transcripts with Apple's on-device Foundation Models LLM (macOS 26+).
///
/// This is the native successor to the Qwen3-via-LLM.swift stack that was ripped out in
/// v1.1.1 for being slow and download-heavy. Foundation Models ships with the OS, runs on
/// the Neural Engine, and — critically for this app's whole premise — never leaves the
/// device. It restores "smart formatting" ambition (real punctuation, capitalization,
/// false-start cleanup) that rule-based regex can only approximate.
///
/// Every path fails soft: if the model is unavailable, the output looks wrong, or an error
/// is thrown, `format(...)` returns `nil` and the pipeline falls back to the rule-based
/// `SmartFormatter`. Dictation flow is never blocked on the LLM.
final class AIFormatter: @unchecked Sendable {
    /// Whether the on-device model is usable right now (eligible hardware, Apple
    /// Intelligence enabled, model downloaded).
    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return true
        case .unavailable: return false
        }
    }

    /// One-line reason the model is unavailable, for surfacing in Settings. `nil` when available.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings to enable AI formatting."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again shortly."
        case .unavailable:
            return "On-device AI formatting isn't available right now."
        }
    }

    /// Transcripts longer than this skip the LLM and use rule-based formatting — keeps
    /// per-utterance latency bounded and avoids the model's context limits.
    private static let maxInputCharacters = 2_000

    /// Returns cleaned text, or `nil` to signal the caller should fall back to rules.
    func format(_ text: String, minimalMode: Bool) async -> String? {
        guard Self.isAvailable else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxInputCharacters else { return nil }

        let instructions = minimalMode ? Self.minimalInstructions : Self.fullInstructions
        do {
            let session = LanguageModelSession(instructions: instructions)
            // Greedy sampling → deterministic, faithful edits (no creative rewriting).
            let response = try await session.respond(
                to: trimmed,
                options: GenerationOptions(sampling: .greedy)
            )
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Guard against the model "answering" the dictation instead of formatting it:
            // a faithful cleanup is never dramatically longer than its input.
            guard !cleaned.isEmpty, cleaned.count <= trimmed.count * 2 + 40 else { return nil }
            return cleaned
        } catch {
            Log.pipeline.error("AIFormatter failed, using rule-based fallback: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Instructions

    private static let fullInstructions = """
    You are a dictation formatter. The user speaks and you receive the raw speech-to-text.
    Return the SAME words, only cleaned up for writing. Rules:
    - Add correct punctuation and capitalization.
    - Remove filler words (um, uh, you know, like) and false starts / self-corrections \
    ("no wait, I mean...") — keep only the intended final wording.
    - Do NOT add, answer, summarize, translate, or change the meaning of anything.
    - Keep the user's original language.
    - Output ONLY the cleaned text, with no preamble, quotes, or commentary.
    """

    private static let minimalInstructions = """
    You are a dictation cleaner for code editors and terminals. The user speaks and you \
    receive the raw speech-to-text. Return the SAME words verbatim, only removing filler \
    words (um, uh, you know) and false starts / self-corrections. Do NOT add punctuation, \
    change capitalization, rephrase, answer, or add anything. Output ONLY the cleaned text.
    """
}
