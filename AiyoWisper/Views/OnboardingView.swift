import SwiftUI

struct OnboardingView: View {
    let appState: AppState
    let modelManager: ModelManager
    @State private var currentStep = 0
    @State private var permissionService = PermissionService()
    @State private var accessibilityTimer: Timer?
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

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [permissionService] _ in
            MainActor.assumeIsolated {
                permissionService.refreshPermissions()
                if permissionService.hasAccessibilityAccess {
                    self.accessibilityTimer?.invalidate()
                    self.accessibilityTimer = nil
                }
            }
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case 1: permissionService.hasMicrophoneAccess
        case 2: permissionService.hasAccessibilityAccess
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
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
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
            Text("Smaller models are faster but less accurate.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(modelManager.availableModels) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .fontWeight(.medium)
                            Text(model.size)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if modelManager.isDownloading && modelManager.currentDownloadModel == model.id {
                            ProgressView()
                                .controlSize(.small)
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
                    .padding(.vertical, 4)
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
    }
}
