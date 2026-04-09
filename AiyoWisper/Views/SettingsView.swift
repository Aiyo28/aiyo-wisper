import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    let modelManager: ModelManager
    let llmModelManager: LLMModelManager
    @ObservedObject var updaterService: UpdaterService
    let shortcutManager: ShortcutManager
    let dictionaryManager: DictionaryManager
    var onModelSelected: (() -> Void)?
    var onLLMModelChanged: (() -> Void)?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralTab(appState: appState, updaterService: updaterService)
            }

            Tab("Input", systemImage: "keyboard") {
                InputTab(shortcutManager: shortcutManager)
            }

            Tab("Formatting", systemImage: "textformat") {
                FormattingTab(appState: appState, llmModelManager: llmModelManager, dictionaryManager: dictionaryManager, onLLMModelChanged: onLLMModelChanged)
            }

            Tab("Command Mode", systemImage: "command") {
                CommandModeTab(appState: appState)
            }

            Tab("Transcription", systemImage: "cpu") {
                TranscriptionTab(appState: appState, modelManager: modelManager, onModelSelected: onModelSelected)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .tint(.purple)
    }
}

// MARK: - General (+ History + About)

private struct GeneralTab: View {
    let appState: AppState
    @ObservedObject var updaterService: UpdaterService
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(Constants.UserDefaultsKeys.characterByCharacterMode) private var characterByCharacterMode = false
    @State private var copiedEntryId: UUID?

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

            Section("Text Injection") {
                Toggle("Character-by-character typing", isOn: $characterByCharacterMode)
                Text("Slower but compatible with Raycast snippets and text expanders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                if appState.transcriptionHistory.isEmpty {
                    ContentUnavailableView {
                        Label("No History", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Your last \(Constants.History.maxPersistentEntries) transcriptions will appear here.")
                    }
                } else {
                    ForEach(appState.transcriptionHistory) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    if entry.isCommand {
                                        Image(systemName: "command")
                                            .font(.caption2)
                                            .foregroundStyle(.purple)
                                    }
                                    Text(entry.date, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.text)
                                    .font(.callout)
                                    .lineLimit(3)
                            }
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
                                    .font(.caption)
                                    .foregroundStyle(copiedEntryId == entry.id ? .green : .secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(copiedEntryId == entry.id ? "Copied" : "Copy to clipboard")
                        }
                    }

                    Button("Clear History", role: .destructive) {
                        appState.clearHistory()
                    }
                    .controlSize(.small)
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updaterService.automaticallyChecksForUpdates },
                    set: { updaterService.automaticallyChecksForUpdates = $0 }
                ))

                Button("Check Now") {
                    updaterService.checkForUpdates()
                }
                .controlSize(.small)
                .disabled(!updaterService.canCheckForUpdates)
            }

            Section("About") {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AIYO Wisper")
                            .fontWeight(.bold)
                        Text("Free, local voice-to-text dictation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Version 0.1.0")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Input (Hotkey + Shortcuts)

private struct InputTab: View {
    let shortcutManager: ShortcutManager
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("Hotkeys") {
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

            Section("Shortcut Phrases") {
                if shortcutManager.shortcuts.isEmpty {
                    ContentUnavailableView {
                        Label("No Shortcuts", systemImage: "text.badge.star")
                    } description: {
                        Text("Add trigger phrases that expand into longer text during dictation.")
                    }
                } else {
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

// MARK: - Formatting (+ Dictionary)

private struct FormattingTab: View {
    let appState: AppState
    let llmModelManager: LLMModelManager
    let dictionaryManager: DictionaryManager
    var onLLMModelChanged: (() -> Void)?
    @State private var preferredLanguage: String
    @State private var autoDetect: Bool
    @State private var minimalFormatting: Bool
    @State private var useLLMCleanup: Bool
    @State private var showingAddDictionarySheet = false

    init(appState: AppState, llmModelManager: LLMModelManager, dictionaryManager: DictionaryManager, onLLMModelChanged: (() -> Void)?) {
        self.appState = appState
        self.llmModelManager = llmModelManager
        self.dictionaryManager = dictionaryManager
        self.onLLMModelChanged = onLLMModelChanged
        _preferredLanguage = State(initialValue: appState.preferredLanguage)
        _autoDetect = State(initialValue: appState.autoDetectLanguage)
        _minimalFormatting = State(initialValue: appState.minimalFormattingForEditors)
        _useLLMCleanup = State(initialValue: appState.useLLMCleanup)
    }

    var body: some View {
        Form {
            Section("AI Text Cleanup") {
                Toggle("Use AI to clean up transcriptions", isOn: $useLLMCleanup)
                    .onChange(of: useLLMCleanup) { _, newValue in
                        appState.useLLMCleanup = newValue
                    }
                    .disabled(!llmModelManager.isModelDownloaded)

                Text("Removes filler words, fixes self-corrections, and adds punctuation using a local AI model. All processing stays on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Constants.LLM.defaultModelName)
                            .fontWeight(.medium)
                        Text("\(Constants.LLM.defaultModelSize) — also used for command mode")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()

                    if llmModelManager.isModelDownloaded {
                        Button("Delete", role: .destructive) {
                            llmModelManager.deleteModel()
                            useLLMCleanup = false
                            appState.useLLMCleanup = false
                            onLLMModelChanged?()
                        }
                        .controlSize(.small)
                    } else if llmModelManager.isDownloading {
                        VStack(alignment: .trailing, spacing: 4) {
                            ProgressView(value: llmModelManager.downloadProgress)
                                .frame(width: 100)
                            HStack(spacing: 8) {
                                Text("\(Int(llmModelManager.downloadProgress * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Button("Cancel") {
                                    llmModelManager.cancelDownload()
                                }
                                .controlSize(.mini)
                            }
                        }
                    } else {
                        Button("Download") {
                            llmModelManager.download()
                            Task {
                                while llmModelManager.isDownloading {
                                    try? await Task.sleep(for: .milliseconds(500))
                                }
                                if llmModelManager.isModelDownloaded {
                                    onLLMModelChanged?()
                                }
                            }
                        }
                        .controlSize(.small)
                    }
                }

                if let error = llmModelManager.downloadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

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

            Section("Dictionary") {
                if dictionaryManager.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Words", systemImage: "character.book.closed")
                    } description: {
                        Text("Add words and names to improve recognition accuracy.")
                    }
                } else {
                    ForEach(dictionaryManager.entries) { entry in
                        HStack {
                            Text(entry.word)
                                .fontWeight(.medium)
                            if let correction = entry.correction {
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(correction)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                dictionaryManager.deleteEntry(id: entry.id)
                            }
                        }
                    }
                }

                Button("Add Word") {
                    showingAddDictionarySheet = true
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddDictionarySheet) {
            AddDictionaryEntrySheet(dictionaryManager: dictionaryManager, isPresented: $showingAddDictionarySheet)
        }
    }
}

private struct AddDictionaryEntrySheet: View {
    let dictionaryManager: DictionaryManager
    @Binding var isPresented: Bool
    @State private var word = ""
    @State private var correction = ""
    @State private var hasCorrection = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Word")
                .font(.headline)

            Form {
                TextField("Word or name", text: $word)
                    .textFieldStyle(.roundedBorder)

                Toggle("Auto-correct spelling", isOn: $hasCorrection)

                if hasCorrection {
                    TextField("Correct form", text: $correction)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)

            Text(hasCorrection
                ? "When Whisper outputs \"\(word)\", it will be replaced with \"\(correction)\"."
                : "Biases Whisper to recognize this word more accurately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    dictionaryManager.addEntry(
                        word: word,
                        correction: hasCorrection ? correction : nil
                    )
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(word.isEmpty || (hasCorrection && correction.isEmpty))
            }
        }
        .padding()
        .frame(width: 360, height: 280)
    }
}

// MARK: - Command Mode

private struct CommandModeTab: View {
    let appState: AppState

    @State private var commandModeEnabled: Bool

    @AppStorage(Constants.UserDefaultsKeys.llmPreset) private var presetRaw: String = Constants.LLM.defaultPreset
    @AppStorage(Constants.UserDefaultsKeys.llmTemperature) private var temperature: Double = Constants.LLM.defaultTemperature
    @AppStorage(Constants.UserDefaultsKeys.llmMaxTokens) private var maxTokens: Int = Constants.LLM.defaultMaxTokens

    init(appState: AppState) {
        self.appState = appState
        _commandModeEnabled = State(initialValue: appState.commandModeEnabled)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable command mode", isOn: $commandModeEnabled)
                    .onChange(of: commandModeEnabled) { _, newValue in
                        appState.commandModeEnabled = newValue
                    }

                Text("Hold Option to speak a command that transforms selected text. Requires the AI model — download it in Settings → Formatting → AI Text Cleanup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quality Preset") {
                Picker("Preset", selection: Binding(
                    get: { presetRaw },
                    set: { newValue in
                        presetRaw = newValue
                        applyPreset(newValue)
                    }
                )) {
                    Text("Fast").tag("fast")
                    Text("Balanced").tag("balanced")
                    Text("Creative").tag("creative")
                }
                .pickerStyle(.segmented)
            }

            Section {
                DisclosureGroup("Advanced") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Temperature")
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1f", temperature))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $temperature, in: 0.0...1.0, step: 0.1)
                            HStack {
                                Text("Deterministic").font(.caption2).foregroundStyle(.tertiary)
                                Spacer()
                                Text("Creative").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Tokens")
                                    .font(.caption)
                                Spacer()
                                Text("\(maxTokens)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(maxTokens) },
                                set: { maxTokens = Int($0) }
                            ), in: 256...4096, step: 128)
                        }

                        HStack {
                            Spacer()
                            Button("Reset to Balanced") {
                                applyPreset("balanced")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func applyPreset(_ preset: String) {
        switch preset {
        case "fast":
            temperature = 0.2
            maxTokens = 512
        case "balanced":
            temperature = Constants.LLM.defaultTemperature
            maxTokens = Constants.LLM.defaultMaxTokens
        case "creative":
            temperature = 0.7
            maxTokens = 2048
        default:
            break
        }
        presetRaw = preset
    }
}

// MARK: - Transcription (formerly Models)

private struct TranscriptionTab: View {
    let appState: AppState
    let modelManager: ModelManager
    var onModelSelected: (() -> Void)?
    @State private var downloadError: String?

    var body: some View {
        Form {
            Section("Speech Recognition Model") {
                ForEach(modelManager.availableModels) { model in
                    ModelRow(
                        model: model,
                        isActive: appState.selectedModel == model.id,
                        isDownloading: modelManager.isDownloading && modelManager.currentDownloadModel == model.id,
                        canDownload: !modelManager.isDownloading,
                        showLanguageWarning: model.englishOnly && (appState.autoDetectLanguage || appState.preferredLanguage != "en"),
                        onSelect: {
                            appState.selectedModel = model.id
                            onModelSelected?()
                        },
                        onDownload: {
                            Task {
                                do {
                                    try await modelManager.download(modelId: model.id)
                                } catch {
                                    downloadError = error.localizedDescription
                                }
                            }
                        },
                        onDelete: {
                            do {
                                try modelManager.deleteModel(model.id)
                            } catch {
                                downloadError = "Failed to delete: \(error.localizedDescription)"
                            }
                            if appState.selectedModel == model.id {
                                if let first = modelManager.availableModels.first(where: \.isDownloaded) {
                                    appState.selectedModel = first.id
                                }
                            }
                        }
                    )
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

private struct ModelRow: View {
    let model: ModelManager.ModelInfo
    let isActive: Bool
    let isDownloading: Bool
    let canDownload: Bool
    var showLanguageWarning: Bool = false
    var onSelect: () -> Void
    var onDownload: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .fontWeight(.medium)
                    Text(model.size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.2), in: Capsule())
                    }
                }
                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if showLanguageWarning {
                    Text("English only — won't work with Russian or auto-detect")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if model.isDownloaded {
                HStack(spacing: 8) {
                    if !isActive {
                        Button("Select", action: onSelect)
                            .controlSize(.small)
                    }
                    Button("Delete", role: .destructive, action: onDelete)
                        .controlSize(.small)
                }
            } else if isDownloading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Download", action: onDownload)
                    .controlSize(.small)
                    .disabled(!canDownload)
            }
        }
    }
}
