import Cocoa
import Foundation

struct SmartFormatter {
    /// Apply all formatting passes to transcribed text.
    func format(_ text: String, modelId: String = "tiny", minimalMode: Bool = false) -> String {
        var result = text

        result = removeFillers(result)
        result = applyCourseCorrections(result)

        if !minimalMode && Constants.Formatting.smallModels.contains(modelId) {
            result = polishPunctuation(result)
        }

        result = result
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    // MARK: - Filler Removal

    private func removeFillers(_ text: String) -> String {
        var result = text
        for pattern in Constants.Formatting.fillerPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        return result
    }

    // MARK: - Course Correction

    private func applyCourseCorrections(_ text: String) -> String {
        var result = text
        for marker in Constants.Formatting.correctionMarkers {
            let pattern = "(?:^|[.!?]\\s*)([^.!?]*?)\\b\(marker)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Punctuation Polish (tiny/base models only)

    private func polishPunctuation(_ text: String) -> String {
        var result = text

        // Capitalize first character
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }

        // Add trailing period if no sentence-ending punctuation
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasSuffix(".") && !trimmed.hasSuffix("!") && !trimmed.hasSuffix("?") {
            result = trimmed + "."
        }

        // Capitalize after sentence boundaries
        result = capitalizeSentenceStarts(result)

        return result
    }

    private func capitalizeSentenceStarts(_ text: String) -> String {
        let pattern = "([.!?])\\s+(\\w)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsString = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let letterRange = match.range(at: 2)
            guard let swiftRange = Range(letterRange, in: result) else { continue }
            let letter = result[swiftRange]
            result.replaceSubrange(swiftRange, with: letter.uppercased())
        }

        return result
    }

    // MARK: - LLM Cleanup

    struct LLMCleanupResult {
        let text: String
        /// True when the failure was a corrupted/unloadable model file. Pipeline uses this
        /// to disable LLM cleanup and delete the bad file. Other failures (timeout, empty
        /// response) keep the LLM backend wired so subsequent calls can retry.
        let modelCorrupted: Bool
    }

    func cleanupWithLLM(_ text: String, backend: any LLMBackend) async -> LLMCleanupResult {
        let parameters = LLMParameters(temperature: 0.2, maxTokens: 512)
        do {
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await backend.complete(
                        systemPrompt: Constants.LLM.cleanupSystemPrompt,
                        userPrompt: text,
                        parameters: parameters
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Constants.LLM.cleanupTimeout))
                    throw LLMError.inferenceTimeout
                }
                let value = try await group.next()!
                group.cancelAll()
                return value
            }
            return LLMCleanupResult(text: result, modelCorrupted: false)
        } catch LLMError.modelCorrupted {
            print("[SmartFormatter] LLM model corrupted — disabling cleanup")
            return LLMCleanupResult(text: text, modelCorrupted: true)
        } catch {
            print("[SmartFormatter] LLM cleanup failed, using regex output: \(error)")
            return LLMCleanupResult(text: text, modelCorrupted: false)
        }
    }

    // MARK: - Minimal Mode Detection

    static func shouldUseMinimalMode(setting: Bool) -> Bool {
        guard setting else { return false }
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""
        return Constants.Formatting.codeEditorBundleIDs.contains(bundleID)
    }
}
