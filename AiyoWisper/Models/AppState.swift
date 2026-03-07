import SwiftUI

enum DictationStatus: String {
    case idle
    case recording
    case transcribing
    case injecting
    case error
    case commandRecording
    case commandTranscribing
    case commandProcessing
    case commandInjecting
}

@Observable
final class AppState {
    var status: DictationStatus = .idle
    var lastTranscription: String = ""
    var lastCommand: String = ""
    var errorMessage: String?
    var isCommandMode: Bool = false
    var isModelLoaded: Bool = false
    var modelLoadProgress: Double = 0
    var isDownloadingModel: Bool = false
    var downloadProgress: Double = 0

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.isOnboarded) var isOnboarded: Bool = false

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.selectedModel) var selectedModel: String = Constants.Models.defaultModel

    var detectedLanguage: String?

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.preferredLanguage) var preferredLanguage: String = Constants.Language.defaultLanguage

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.autoDetectLanguage) var autoDetectLanguage: Bool = false

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.minimalFormattingForEditors) var minimalFormattingForEditors: Bool = true

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.llmEndpoint) var llmEndpoint: String = Constants.LLM.defaultEndpoint

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.llmModel) var llmModel: String = Constants.LLM.defaultModel

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.commandModeEnabled) var commandModeEnabled: Bool = true

    var isRecordingAny: Bool { status == .recording || status == .commandRecording }
}
