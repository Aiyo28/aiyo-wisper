import SwiftUI

enum DictationStatus: String {
    case idle
    case recording
    case transcribing
    case injecting
    case error
}

@Observable
final class AppState {
    var status: DictationStatus = .idle
    var lastTranscription: String = ""
    var errorMessage: String?
    var isModelLoaded: Bool = false
    var modelLoadProgress: Double = 0
    var isDownloadingModel: Bool = false
    var downloadProgress: Double = 0

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.isOnboarded) var isOnboarded: Bool = false

    @ObservationIgnored
    @AppStorage(Constants.UserDefaultsKeys.selectedModel) var selectedModel: String = Constants.Models.defaultModel
}
