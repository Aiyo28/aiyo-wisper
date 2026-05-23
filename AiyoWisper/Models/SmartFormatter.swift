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
            // Require an explicit punctuation boundary (comma OR sentence-ender) right
            // before the marker. Whisper output rarely has periods, so anchoring on
            // `^` (start of string) would mean a casual use of "sorry" / "I mean"
            // anywhere in a long sentence strips everything before it — silently
            // nuking entire dictations.
            let pattern = "[,.!?]\\s*([^.!?,]*?)\\b\(marker)"
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

    // MARK: - Minimal Mode Detection

    static func shouldUseMinimalMode(setting: Bool) -> Bool {
        guard setting else { return false }
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""
        return Constants.Formatting.codeEditorBundleIDs.contains(bundleID)
    }
}
