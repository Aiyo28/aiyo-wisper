import SwiftUI

struct OnboardingView: View {
    let appState: AppState
    let modelManager: ModelManager
    var onComplete: (() -> Void)?
    @State private var currentStep = 0
    @State private var permissionService = PermissionService()
    @State private var downloadError: String?
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<5) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)

            Spacer()

            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: microphoneStep
                case 2: accessibilityStep
                case 3: modelStep
                case 4: testStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)

            Spacer()

            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                Button(currentStep == 4 ? "Finish" : "Continue") {
                    if currentStep == 4 {
                        appState.isOnboarded = true
                        onComplete?()
                        dismissWindow(id: "onboarding")
                    } else {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
            .padding(24)
        }
        .frame(width: 520, height: 520)
    }

    private var canContinue: Bool {
        switch currentStep {
        case 3: modelManager.availableModels.contains(where: \.isDownloaded)
        default: true
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Welcome to AIYO Wisper")
                .font(.title)
                .fontWeight(.bold)
            Text("Free, local voice-to-text dictation for macOS.\nHold Control, speak, and text appears wherever your cursor is.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: permissionService.hasMicrophoneAccess ? "mic.circle.fill" : "mic.circle")
                .font(.system(size: 48))
                .foregroundColor(permissionService.hasMicrophoneAccess ? .green : .accentColor)
            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Audio is processed entirely on your device — nothing leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if permissionService.hasMicrophoneAccess {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if permissionService.microphoneWasDenied {
                Text("Permission was denied. Please enable it in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Open System Settings") {
                    permissionService.openMicrophoneSettings()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Grant Microphone Access") {
                    Task {
                        await permissionService.requestMicrophonePermission()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            permissionService.refreshPermissions()
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: permissionService.hasAccessibilityAccess ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(permissionService.hasAccessibilityAccess ? .green : .accentColor)
            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Required for global hotkey detection and typing text into other apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if permissionService.hasAccessibilityAccess {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings") {
                    permissionService.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            permissionService.refreshPermissions()
        }
    }

    private var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Download a Model")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Pick a speech recognition model to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                ForEach(modelManager.availableModels) { model in
                    VStack(spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(model.name)
                                        .fontWeight(.medium)
                                    Text(model.size)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if model.id == "small" {
                                        Text("Recommended")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.2), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                }
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if model.isDownloaded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if modelManager.isDownloading && modelManager.currentDownloadModel == model.id {
                                Button("Cancel") {
                                    // Cancel not implemented for WhisperKit downloads yet
                                }
                                .controlSize(.small)
                                .disabled(true)
                            } else {
                                Button("Download") {
                                    Task {
                                        do {
                                            try await modelManager.download(modelId: model.id)
                                            appState.selectedModel = model.id
                                        } catch {
                                            downloadError = error.localizedDescription
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(modelManager.isDownloading)
                            }
                        }

                        if modelManager.isDownloading && modelManager.currentDownloadModel == model.id {
                            ProgressView(value: modelManager.downloadProgress)
                                .progressViewStyle(.linear)
                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
            }

            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var testStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Ready to Go!")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Hold the Control key and speak. Release to see transcribed text appear at your cursor.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            GroupBox {
                if !appState.lastTranscription.isEmpty {
                    Text(appState.lastTranscription)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                } else {
                    Text("Try it now — your transcription will appear here...")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
            }
        }
        .onAppear {
            // Start pipeline early so user can test dictation before finishing
            onComplete?()
        }
    }
}
