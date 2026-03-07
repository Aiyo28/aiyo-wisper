import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    let modelManager: ModelManager
    let shortcutManager: ShortcutManager
    var onModelSelected: (() -> Void)?
    var onLLMSettingsChanged: (() -> Void)?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralTab()
            }

            Tab("Hotkey", systemImage: "keyboard") {
                HotkeyTab()
            }

            Tab("Formatting", systemImage: "textformat") {
                FormattingTab(appState: appState)
            }

            Tab("Command Mode", systemImage: "command") {
                CommandModeTab(appState: appState, onLLMSettingsChanged: onLLMSettingsChanged)
            }

            Tab("Shortcuts", systemImage: "text.badge.star") {
                ShortcutsTab(shortcutManager: shortcutManager)
            }

            Tab("Models", systemImage: "cpu") {
                ModelsTab(appState: appState, modelManager: modelManager, onModelSelected: onModelSelected)
            }

            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkey

private struct HotkeyTab: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Dictation hotkey")
                    Spacer()
                    Text("Control (hold)")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }

                HStack {
                    Text("Command hotkey")
                    Spacer()
                    Text("Option (hold)")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Formatting

private struct FormattingTab: View {
    let appState: AppState
    @State private var preferredLanguage: String
    @State private var autoDetect: Bool
    @State private var minimalFormatting: Bool

    init(appState: AppState) {
        self.appState = appState
        _preferredLanguage = State(initialValue: appState.preferredLanguage)
        _autoDetect = State(initialValue: appState.autoDetectLanguage)
        _minimalFormatting = State(initialValue: appState.minimalFormattingForEditors)
    }

    var body: some View {
        Form {
            Section("Language") {
                Picker("Preferred language", selection: $preferredLanguage) {
                    ForEach(Constants.Language.available, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: preferredLanguage) { _, newValue in
                    appState.preferredLanguage = newValue
                }

                Toggle("Auto-detect language", isOn: $autoDetect)
                    .onChange(of: autoDetect) { _, newValue in
                        appState.autoDetectLanguage = newValue
                    }

                if autoDetect {
                    Text("Whisper will detect the spoken language automatically. Works best with larger models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Formatting") {
                Toggle("Minimal formatting for code editors", isOn: $minimalFormatting)
                    .onChange(of: minimalFormatting) { _, newValue in
                        appState.minimalFormattingForEditors = newValue
                    }

                Text("Skips punctuation and capitalization when dictating into VS Code, Xcode, Terminal, and other code editors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Command Mode

private struct CommandModeTab: View {
    let appState: AppState
    var onLLMSettingsChanged: (() -> Void)?

    @State private var commandModeEnabled: Bool
    @State private var llmEndpoint: String
    @State private var llmModel: String
    @State private var connectionStatus: ConnectionStatus = .idle

    private enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success
        case failure
    }

    init(appState: AppState, onLLMSettingsChanged: (() -> Void)?) {
        self.appState = appState
        self.onLLMSettingsChanged = onLLMSettingsChanged
        _commandModeEnabled = State(initialValue: appState.commandModeEnabled)
        _llmEndpoint = State(initialValue: appState.llmEndpoint)
        _llmModel = State(initialValue: appState.llmModel)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable command mode", isOn: $commandModeEnabled)
                    .onChange(of: commandModeEnabled) { _, newValue in
                        appState.commandModeEnabled = newValue
                    }
            }

            Section("LLM Server") {
                TextField("Endpoint URL", text: $llmEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: llmEndpoint) { _, newValue in
                        appState.llmEndpoint = newValue
                        onLLMSettingsChanged?()
                    }

                TextField("Model name", text: $llmModel)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: llmModel) { _, newValue in
                        appState.llmModel = newValue
                        onLLMSettingsChanged?()
                    }

                HStack {
                    Button("Test Connection") {
                        connectionStatus = .testing
                        Task {
                            let service = LLMService(endpointURL: llmEndpoint, modelName: llmModel)
                            let success = await service.testConnection()
                            connectionStatus = success ? .success : .failure
                        }
                    }
                    .disabled(connectionStatus == .testing || llmEndpoint.isEmpty)

                    switch connectionStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failure:
                        Label("Connection failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    let shortcutManager: ShortcutManager
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            if shortcutManager.shortcuts.isEmpty {
                ContentUnavailableView {
                    Label("No Shortcuts", systemImage: "text.badge.star")
                } description: {
                    Text("Add trigger phrases that expand into longer text during dictation.")
                }
            } else {
                Section("Trigger Phrases") {
                    List {
                        ForEach(shortcutManager.shortcuts) { shortcut in
                            HStack {
                                Text(shortcut.trigger)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(shortcut.expansion)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    shortcutManager.deleteShortcut(id: shortcut.id)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button("Add Shortcut") {
                    showingAddSheet = true
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            AddShortcutSheet(shortcutManager: shortcutManager, isPresented: $showingAddSheet)
        }
    }
}

private struct AddShortcutSheet: View {
    let shortcutManager: ShortcutManager
    @Binding var isPresented: Bool
    @State private var trigger = ""
    @State private var expansion = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Shortcut")
                .font(.headline)

            Form {
                TextField("Trigger phrase", text: $trigger)
                    .textFieldStyle(.roundedBorder)
                TextField("Expands to", text: $expansion)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    shortcutManager.addShortcut(trigger: trigger, expansion: expansion)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trigger.isEmpty || expansion.isEmpty)
            }
        }
        .padding()
        .frame(width: 360, height: 240)
    }
}

// MARK: - Models

private struct ModelsTab: View {
    let appState: AppState
    let modelManager: ModelManager
    var onModelSelected: (() -> Void)?
    @State private var downloadError: String?

    var body: some View {
        Form {
            Section("Available Models") {
                ForEach(modelManager.availableModels) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 6) {
                                Text(model.name)
                                    .fontWeight(.medium)
                                if appState.selectedModel == model.id {
                                    Text("Active")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.tint.opacity(0.2), in: Capsule())
                                }
                            }
                            Text(model.size)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isDownloaded {
                            HStack(spacing: 8) {
                                if appState.selectedModel != model.id {
                                    Button("Select") {
                                        appState.selectedModel = model.id
                                        onModelSelected?()
                                    }
                                    .controlSize(.small)
                                }
                                Button("Delete", role: .destructive) {
                                    do {
                                        try modelManager.deleteModel(model.id)
                                    } catch {
                                        downloadError = "Failed to delete model: \(error.localizedDescription)"
                                    }
                                    if appState.selectedModel == model.id {
                                        if let first = modelManager.availableModels.first(where: \.isDownloaded) {
                                            appState.selectedModel = first.id
                                        }
                                    }
                                }
                                .controlSize(.small)
                            }
                        } else if modelManager.isDownloading && modelManager.currentDownloadModel == model.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Download") {
                                Task {
                                    do {
                                        try await modelManager.download(modelId: model.id)
                                    } catch {
                                        downloadError = error.localizedDescription
                                    }
                                }
                            }
                            .controlSize(.small)
                            .disabled(modelManager.isDownloading)
                        }
                    }
                }
            }

            if let error = downloadError {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("AIYO Wisper")
                .font(.title2)
                .fontWeight(.bold)
            Text("Free, local voice-to-text dictation")
                .foregroundStyle(.secondary)
            Text("Version 0.1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
