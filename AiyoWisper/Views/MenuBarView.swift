import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let modelManager: ModelManager
    @ObservedObject var updaterService: UpdaterService
    @Environment(\.openSettings) private var openSettings
    @State private var copiedEntryId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.headline)
            }

            Divider()

            if !appState.transcriptionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent transcriptions:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(appState.transcriptionHistory.prefix(Constants.History.maxPersistentEntries)) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            if entry.isCommand {
                                Image(systemName: "command")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                            }
                            Text(entry.text)
                                .font(.callout)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.text, forType: .string)
                                copiedEntryId = entry.id
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    if copiedEntryId == entry.id {
                                        copiedEntryId = nil
                                    }
                                }
                            } label: {
                                Image(systemName: copiedEntryId == entry.id ? "checkmark" : "doc.on.doc")
                                    .font(.caption2)
                                    .foregroundStyle(copiedEntryId == entry.id ? .green : .secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(copiedEntryId == entry.id ? "Copied" : "Copy to clipboard")
                        }
                    }
                }

                Divider()
            }

            HStack {
                Text("Model:")
                    .foregroundStyle(.secondary)
                Text(appState.selectedModel)
                    .fontWeight(.medium)
                if appState.isModelLoaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .font(.caption)

            HStack {
                Text("Language:")
                    .foregroundStyle(.secondary)
                if appState.autoDetectLanguage {
                    Text("Auto")
                        .fontWeight(.medium)
                    if let detected = appState.detectedLanguage {
                        Text("(\(detected))")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(appState.preferredLanguage.uppercased())
                        .fontWeight(.medium)
                }
            }
            .font(.caption)

            if let error = appState.errorMessage {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                if error.contains("Accessibility") {
                    Button("Open Accessibility Settings") {
                        PermissionService.openAccessibilitySettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            Button("Settings...") {
                openSettingsToFront()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Check for Updates...") {
                updaterService.checkForUpdates()
            }
            .disabled(!updaterService.canCheckForUpdates)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 260)
    }

    /// MenuBarExtra apps don't activate when SettingsLink fires, so the window opens behind
    /// whatever app is frontmost. Activate explicitly, then raise the Settings window once
    /// SwiftUI has created it.
    private func openSettingsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        DispatchQueue.main.async {
            raiseSettingsWindow()
        }
    }

    private func raiseSettingsWindow() {
        let settingsWindow = NSApp.windows.first { window in
            // SwiftUI's Settings scene uses this frame autosave name; fall back to title match.
            window.frameAutosaveName == "com_apple_SwiftUI_Settings_window"
                || window.title == "AIYO Wisper Settings"
                || window.title.localizedCaseInsensitiveContains("settings")
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle: appState.isModelLoaded ? .green : .orange
        case .recording: .red
        case .transcribing: .orange
        case .cleaning: .cyan
        case .injecting: .blue
        case .error: .red
        case .commandRecording: .purple
        case .commandTranscribing: .purple
        case .commandProcessing: .purple
        case .commandInjecting: .purple
        }
    }

    private var statusText: String {
        switch appState.status {
        case .idle: appState.isModelLoaded ? "Ready" : "Model Not Ready"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .cleaning: "Cleaning up..."
        case .injecting: "Injecting text..."
        case .error: "Error"
        case .commandRecording: "Command Mode..."
        case .commandTranscribing: "Transcribing command..."
        case .commandProcessing: "Processing..."
        case .commandInjecting: "Injecting..."
        }
    }
}
