import Foundation

enum Constants {
    static let appName = "AIYO Wisper"
    static let bundleId = "com.aiyo.wisper"

    enum Hotkey {
        static let defaultKeyCode: UInt16 = 63 // fn key
    }

    enum Audio {
        static let sampleRate: Double = 16_000
        static let channels: Int = 1
        static let minimumRecordingDuration: TimeInterval = 0.3
    }

    enum Models {
        static let defaultModel = "tiny"
        static let supportDirectory = "AiyoWisper/Models"

        static var modelsDirectory: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent(supportDirectory, isDirectory: true)
        }

        static let available: [(name: String, size: String, description: String)] = [
            ("tiny", "75 MB", "Fastest, least accurate"),
            ("base", "150 MB", "Good balance for quick tasks"),
            ("small", "500 MB", "Better accuracy, moderate speed"),
            ("medium", "1.5 GB", "High accuracy, slower"),
            ("large", "3 GB", "Best accuracy, slowest"),
        ]
    }

    enum UserDefaultsKeys {
        static let isOnboarded = "isOnboarded"
        static let selectedModel = "selectedModel"
        static let preferredLanguage = "preferredLanguage"
        static let autoDetectLanguage = "autoDetectLanguage"
        static let minimalFormattingForEditors = "minimalFormattingForEditors"
        static let llmEndpoint = "llmEndpoint"
        static let llmModel = "llmModel"
        static let commandModeEnabled = "commandModeEnabled"
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

        static let smallModels: Set<String> = ["tiny", "base"]
    }

    enum LLM {
        static let defaultEndpoint = "http://localhost:11434/v1"
        static let defaultModel = "llama3.2:3b"
        static let requestTimeout: TimeInterval = 30
    }

    enum CommandMode {
        static let clipboardReadDelay: UInt32 = 100_000 // microseconds
        static let clipboardRestoreDelay: TimeInterval = 0.5
    }

    enum Language {
        static let available: [(code: String, name: String)] = [
            ("en", "English"),
            ("ru", "Russian"),
        ]
        static let defaultLanguage = "en"
    }
}
