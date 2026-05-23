import Foundation

enum Constants {
    static let appName = "AIYO Wisper"
    static let bundleId = "com.aiyo.wisper"

    enum Audio {
        static let sampleRate: Double = 16_000
        static let channels: Int = 1
        static let minimumRecordingDuration: TimeInterval = 0.3
    }

    enum Models {
        static let defaultModel = "small"
        static let supportDirectory = "AiyoWisper/Models"

        static var modelsDirectory: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent(supportDirectory, isDirectory: true)
        }
    }

    enum UserDefaultsKeys {
        static let isOnboarded = "isOnboarded"
        static let selectedModel = "selectedModel"
        static let preferredLanguage = "preferredLanguage"
        static let autoDetectLanguage = "autoDetectLanguage"
        static let minimalFormattingForEditors = "minimalFormattingForEditors"
        static let characterByCharacterMode = "characterByCharacterMode"
    }

    enum TextInjection {
        static let interCharacterDelay: UInt32 = 5_000 // microseconds
        static let terminalBundleIDs: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
        ]
    }

    enum Formatting {
        static let fillerPatterns: [String] = [
            "\\b(?:um|uh|erm|ah)\\b,?\\s*",
            "\\byou know,?\\s*",
            "\\bbasically,?\\s*",
            "\\blike,?\\s+(?=\\w)",
            "\\bI mean,?\\s+",
            "\\bso,?\\s+(?=so\\b|basically\\b|like\\b|anyway\\b)",
        ]

        static let correctionMarkers: [String] = [
            "no wait,?\\s*",
            "I meant?,?\\s*",
            "sorry,?\\s*",
            "actually no,?\\s*",
            "let me rephrase,?\\s*",
            "what I meant (?:is|was),?\\s*",
        ]

        static let codeEditorBundleIDs: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "dev.zed.Zed",
            "com.sublimetext.4",
            "com.jetbrains.intellij",
        ]

        static let smallModels: Set<String> = ["tiny"] // Models that need extra punctuation polish
    }

    enum History {
        static let maxPersistentEntries = 6

        static var historyFileURL: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("AiyoWisper/history.json", isDirectory: false)
        }
    }

    enum Dictionary {
        static var dictionaryFileURL: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("AiyoWisper/dictionary.json", isDirectory: false)
        }

        /// How long DictationLearner waits after an injection before sampling the focused
        /// field to detect user corrections. Long enough for a user to notice an error
        /// and start fixing it; short enough that we don't drift across user actions or
        /// invite focus changes that would defeat the AX-role safety gates.
        static let observationDelay: TimeInterval = 12
    }

    enum Language {
        static let available: [(code: String, name: String)] = [
            ("en", "English"),
            ("ru", "Russian"),
        ]
        static let defaultLanguage = "en"
    }
}
