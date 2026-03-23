import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    let modelManager: ModelManager
    let shortcutManager: ShortcutManager
    let dictionaryManager: DictionaryManager
    var onModelSelected: (() -> Void)?
    var onLLMSettingsChanged: (() -> Void)?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralTab(appState: appState)
            }

            Tab("Input", systemImage: "keyboard") {
                InputTab(shortcutManager: shortcutManager)
            }

            Tab("Formatting", systemImage: "textformat") {
                FormattingTab(appState: appState, dictionaryManager: dictionaryManager)
            }

            Tab("Command Mode", systemImage: "command") {
                CommandModeTab(appState: appState, onLLMSettingsChanged: onLLMSettingsChanged)
            }

            Tab("Transcription", systemImage: "cpu") {
                TranscriptionTab(appState: appState, modelManager: modelManager, onModelSelected: onModelSelected)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
    }
}

// MARK: - General (+ History + About)

private struct GeneralTab: View {
    let appState: AppState
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
    let dictionaryManager: DictionaryManager
    @State private var preferredLanguage: String
    @State private var autoDetect: Bool
    @State private var minimalFormatting: Bool
    @State private var showingAddDictionarySheet = false

    init(appState: AppState, dictionaryManager: DictionaryManager) {
        self.appState = appState
        self.dictionaryManager = dictionaryManager
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
    var onLLMSettingsChanged: (() -> Void)?

    @State private var commandModeEnabled: Bool
    @State private var llmEndpoint: String
    @State private var llmModel: String
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var ollamaModels: [OllamaModel] = []
    @State private var isLoadingModels = false
    @State private var pullTask: Task<Void, Never>?
    @State private var pullingModelName: String?
    @State private var pullProgress: Double = 0
    @State private var pullError: String?

    @AppStorage(Constants.UserDefaultsKeys.llmPreset) private var presetRaw: String = Constants.LLM.defaultPreset
    @AppStorage(Constants.UserDefaultsKeys.llmTemperature) private var temperature: Double = Constants.LLM.defaultTemperature
    @AppStorage(Constants.UserDefaultsKeys.llmRepeatPenalty) private var repeatPenalty: Double = Constants.LLM.defaultRepeatPenalty
    @AppStorage(Constants.UserDefaultsKeys.llmFrequencyPenalty) private var frequencyPenalty: Double = Constants.LLM.defaultFrequencyPenalty
    @AppStorage(Constants.UserDefaultsKeys.llmMaxTokens) private var maxTokens: Int = Constants.LLM.defaultMaxTokens

    private var preset: LLMPreset {
        LLMPreset(rawValue: presetRaw) ?? .balanced
    }

    private enum ConnectionStatus: Equatable {
        case idle
        case testing
        case connected
        case notRunning
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
                    .onSubmit { checkConnection() }

                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    switch connectionStatus {
                    case .idle:
                        Label("Unknown", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                    case .connected:
                        Label("Connected", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    case .notRunning:
                        Label("Not Running", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            if connectionStatus == .notRunning {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ollama is required for command mode.")
                            .font(.caption)
                        Text("Download at ollama.ai")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }

            if connectionStatus == .connected {
                modelSection
                presetSection
                advancedSection
            }
        }
        .formStyle(.grouped)
        .onAppear { checkConnection() }
    }

    // MARK: - Model Section

    @ViewBuilder
    private var modelSection: some View {
        Section("Model") {
            if isLoadingModels {
                ProgressView("Loading models...")
                    .controlSize(.small)
            } else if ollamaModels.isEmpty {
                Text("No models found. Pull a model to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(ollamaModels, id: \.name) { model in
                ollamaModelRow(model)
            }

            ForEach(registryModelsNotPulled, id: \.name) { info in
                unpulledModelRow(info)
            }
        }
    }

    private func ollamaModelRow(_ model: OllamaModel) -> some View {
        let isActive = llmModel == model.name
        let info = LLMModelInfo.find(model.name)

        return HStack {
            Circle()
                .fill(isActive ? Color.green : Color.blue)
                .frame(width: 8, height: 8)
                .accessibilityLabel(isActive ? "Active" : "Downloaded")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .fontWeight(.medium)
                Text(info?.description ?? "Custom model")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isActive {
                Text("Active")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(.green)
            } else {
                Button("Select") {
                    llmModel = model.name
                    appState.llmModel = model.name
                    applyPreset(preset, for: model.name)
                    onLLMSettingsChanged?()
                }
                .controlSize(.small)
            }
        }
    }

    private func unpulledModelRow(_ info: LLMModelInfo) -> some View {
        let isPulling = pullingModelName == info.name

        return HStack {
            Circle()
                .fill(isPulling ? Color.yellow : Color.gray)
                .frame(width: 8, height: 8)
                .accessibilityLabel(isPulling ? "Downloading" : "Not downloaded")

            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .fontWeight(.medium)
                    .foregroundStyle(isPulling ? .primary : .secondary)
                HStack(spacing: 4) {
                    Text(info.size)
                    Text("—")
                    Text(info.description)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                if isPulling {
                    ProgressView(value: pullProgress)
                        .progressViewStyle(.linear)
                    Text("\(Int(pullProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let error = pullError, pullingModelName == nil && info.name == pullError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if isPulling {
                Button("Cancel") {
                    pullTask?.cancel()
                    pullTask = nil
                    pullingModelName = nil
                    pullProgress = 0
                }
                .controlSize(.small)
            } else {
                Button("Pull") {
                    startPull(info.name)
                }
                .controlSize(.small)
                .disabled(pullingModelName != nil)
            }
        }
        .opacity(isPulling ? 1 : 0.6)
    }

    private var registryModelsNotPulled: [LLMModelInfo] {
        let pulledNames = Set(ollamaModels.map(\.name))
        return LLMModelInfo.registry.filter { !pulledNames.contains($0.name) }
    }

    // MARK: - Preset Section

    @ViewBuilder
    private var presetSection: some View {
        Section("Quality Preset") {
            Picker("Preset", selection: Binding(
                get: { presetRaw },
                set: { newValue in
                    presetRaw = newValue
                    if let p = LLMPreset(rawValue: newValue) {
                        applyPreset(p, for: llmModel)
                    }
                }
            )) {
                Text("Fast").tag("fast")
                Text("Balanced").tag("balanced")
                Text("Creative").tag("creative")
                if presetRaw == "custom" {
                    Text("Custom").tag("custom")
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Advanced Section

    @ViewBuilder
    private var advancedSection: some View {
        Section {
            DisclosureGroup("Advanced") {
                VStack(alignment: .leading, spacing: 16) {
                    sliderRow("Temperature", value: $temperature, range: 0.0...1.0, step: 0.1, low: "Deterministic", high: "Creative")
                    sliderRow("Repetition Penalty", value: $repeatPenalty, range: 1.0...2.0, step: 0.1, low: "Off (1.0)", high: "Strong (2.0)")
                    sliderRow("Frequency Penalty", value: $frequencyPenalty, range: 0.0...2.0, step: 0.1, low: "Off (0.0)", high: "Strong (2.0)")

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
                            set: { maxTokens = Int($0); markCustom() }
                        ), in: 256...4096, step: 128)
                    }

                    HStack {
                        Spacer()
                        Button("Reset to Preset Defaults") {
                            if let p = LLMPreset(rawValue: presetRaw == "custom" ? "balanced" : presetRaw) {
                                presetRaw = p.rawValue
                                applyPreset(p, for: llmModel)
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0; markCustom() }
            ), in: range, step: step)
            HStack {
                Text(low).font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(high).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func checkConnection() {
        connectionStatus = .testing
        let service = OllamaService(llmEndpoint: llmEndpoint)
        Task {
            let running = await service.isRunning()
            connectionStatus = running ? .connected : .notRunning
            if running {
                await loadModels()
            }
        }
    }

    private func loadModels() async {
        isLoadingModels = true
        let service = OllamaService(llmEndpoint: llmEndpoint)
        do {
            ollamaModels = try await service.listModels()
        } catch {
            ollamaModels = []
        }
        isLoadingModels = false
    }

    private func startPull(_ name: String) {
        pullError = nil
        pullingModelName = name
        pullProgress = 0
        let service = OllamaService(llmEndpoint: llmEndpoint)
        pullTask = Task {
            do {
                try await service.pullModel(name: name) { progress in
                    Task { @MainActor in
                        pullProgress = progress
                    }
                }
                pullingModelName = nil
                pullProgress = 0
                await loadModels()
            } catch is CancellationError {
                pullingModelName = nil
                pullProgress = 0
            } catch {
                pullError = error.localizedDescription
                pullingModelName = nil
                pullProgress = 0
            }
        }
    }

    private func applyPreset(_ preset: LLMPreset, for model: String) {
        let params = LLMModelInfo.presetParameters(for: model, preset: preset)
        temperature = params.temperature
        repeatPenalty = params.repeatPenalty
        frequencyPenalty = params.frequencyPenalty
        maxTokens = params.maxTokens
    }

    private func markCustom() {
        presetRaw = "custom"
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
            ForEach(ModelManager.ModelCategory.allCases, id: \.rawValue) { category in
                Section(category.rawValue) {
                    ForEach(modelManager.models(for: category)) { model in
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
