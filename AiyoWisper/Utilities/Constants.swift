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
}
