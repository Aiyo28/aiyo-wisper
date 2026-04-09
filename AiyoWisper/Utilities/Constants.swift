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
        static let defaultModel = "large-v3-turbo"
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
            ("large-v3", "3 GB", "Best accuracy, slowest"),
            ("large-v3-turbo", "~600 MB", "Near large-v3 accuracy, 6x faster"),
            ("distil-large-v3", "~600 MB", "Near large-v3 accuracy, English only"),
        ]
    }

    enum UserDefaultsKeys {
        static let isOnboarded = "isOnboarded"
        static let selectedModel = "selectedModel"
        static let preferredLanguage = "preferredLanguage"
        static let autoDetectLanguage = "autoDetectLanguage"
        static let minimalFormattingForEditors = "minimalFormattingForEditors"
        static let commandModeEnabled = "commandModeEnabled"
        static let characterByCharacterMode = "characterByCharacterMode"
        static let llmTemperature = "llmTemperature"
        static let llmMaxTokens = "llmMaxTokens"
        static let llmPreset = "llmPreset"
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

    enum LLM {
        static let defaultTemperature: Double = 0.5
        static let defaultMaxTokens: Int = 1024
        static let defaultPreset: String = "balanced"
        static let cleanupTimeout: TimeInterval = 5

        static let cleanupSystemPrompt = """
            Clean up this speech transcription. Remove filler words, self-corrections, \
            and disfluencies. Add proper punctuation and capitalization. \
            Output only the cleaned text, nothing else.
            """

        static let commandSystemPrompt = """
            You are a text transformation assistant. You receive selected text and a voice command. \
            Apply the command to transform the text. Output ONLY the transformed text. \
            Do not add explanations, markdown formatting, or quotes around the output. \
            Preserve the original formatting style unless the command requires changing it.
            """

        static let defaultModelRepo = "Qwen/Qwen3.5-4B-GGUF"
        static let defaultModelFile = "qwen3.5-4b-q4_k_m.gguf"
        static let defaultModelName = "Qwen 3.5 4B"
        static let defaultModelSize = "~2.5 GB"

        static var llmModelsDirectory: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("AiyoWisper/LLMModels", isDirectory: true)
        }

        static var defaultModelPath: URL {
            llmModelsDirectory.appendingPathComponent(defaultModelFile)
        }
    }

    enum UserDefaultsKeys2 {
        static let useLLMCleanup = "useLLMCleanup"
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
