import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let modelManager: ModelManager
    @ObservedObject var updaterService: UpdaterService
    var onLanguageChange: (() -> Void)?
    @Environment(\.openSettings) private var openSettings
    @State private var copiedEntryId: UUID?

    /// Languages to offer for the active engine. The Apple engine only lists what it can
    /// actually serve on this OS (English for now; more appear as macOS adds them);
    /// WhisperKit is multilingual, so it lists everything.
    private var offeredLanguages: [(code: String, name: String)] {
        guard appState.transcriptionEngine == .apple else { return Constants.Language.available }
        return Constants.Language.available.filter { appState.appleSupportedLanguages.contains($0.code) }
    }

    /// Language control for the menu bar. "Auto" spans every offered language and keeps the
    /// most confident transcript; picking a specific language pins it. Either way the engine
    /// re-prepares immediately — no Settings trip.
    private var languageBinding: Binding<String> {
        Binding(
            get: { appState.autoDetectLanguage ? "auto" : appState.preferredLanguage },
            set: { selection in
                if selection == "auto" {
                    appState.autoDetectLanguage = true
                } else {
                    appState.autoDetectLanguage = false
                    appState.preferredLanguage = selection
                }
                onLanguageChange?()
            }
        )
    }

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
                Picker("Language", selection: languageBinding) {
                    Text("Auto").tag("auto")
                    ForEach(offeredLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                if appState.autoDetectLanguage, let detected = appState.detectedLanguage {
                    Text("(\(detected))")
                        .foregroundStyle(.secondary)
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
        case .injecting: .blue
        case .error: .red
        }
    }

    private var statusText: String {
        switch appState.status {
        case .idle: appState.isModelLoaded ? "Ready" : "Model Not Ready"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .injecting: "Injecting text..."
        case .error: "Error"
        }
    }
}
