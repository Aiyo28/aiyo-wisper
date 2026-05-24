import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    let modelManager: ModelManager
    @ObservedObject var updaterService: UpdaterService
    let shortcutManager: ShortcutManager
    let dictionaryManager: DictionaryManager
    let learner: DictationLearner
    var onModelSelected: (() -> Void)?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralTab(appState: appState, updaterService: updaterService)
            }

            Tab("Input", systemImage: "keyboard") {
                InputTab(shortcutManager: shortcutManager)
            }

            Tab("Formatting", systemImage: "textformat") {
                FormattingTab(appState: appState, dictionaryManager: dictionaryManager, learner: learner)
            }

            Tab("Transcription", systemImage: "cpu") {
                TranscriptionTab(appState: appState, modelManager: modelManager, onModelSelected: onModelSelected)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .tint(.blue)
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
                                Text(entry.date, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
                        Text("Version \(Bundle.main.appVersion)")
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
            Section("Hotkey") {
                HStack {
                    Text("Dictation hotkey")
                    Spacer()
                    Text("Control (hold)")
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
    let learner: DictationLearner
    @State private var preferredLanguage: String
    @State private var autoDetect: Bool
    @State private var minimalFormatting: Bool
    @State private var showingAddDictionarySheet = false

    init(appState: AppState, dictionaryManager: DictionaryManager, learner: DictationLearner) {
        self.appState = appState
        self.dictionaryManager = dictionaryManager
        self.learner = learner
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

            if !learner.suggestions.isEmpty {
                Section {
                    ForEach(learner.suggestions) { suggestion in
                        HStack {
                            Text(suggestion.original)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text(suggestion.suggested)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                learner.acceptSuggestion(suggestion.id, dictionaryManager: dictionaryManager)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .help("Add to dictionary")

                            Button {
                                learner.dismissSuggestion(suggestion.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Dismiss")
                        }
                    }
                } header: {
                    HStack {
                        Text("Suggested Corrections")
                        Spacer()
                        Button("Dismiss All") {
                            learner.clearAllSuggestions()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                } footer: {
                    Text("Detected from your edits after dictation. Accept to auto-correct future transcriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Dictionary") {
                if dictionaryManager.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Words", systemImage: "character.book.closed")
                    } description: {
                        Text("Add words and names to improve recognition accuracy. Wisper also auto-learns from edits you make after dictation.")
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
                        downloadProgress: modelManager.downloadProgress,
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
    var downloadProgress: Double = 0
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
                    Text("[\(model.id)]")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
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
                    Text("English only — will not transcribe other languages, and won't work with auto-detect")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if model.isDownloaded {
                if isActive {
                    Button("Delete", role: .destructive, action: onDelete)
                        .controlSize(.small)
                } else {
                    HStack(spacing: 8) {
                        Button("Select", action: onSelect)
                            .controlSize(.small)
                        Button("Delete", role: .destructive, action: onDelete)
                            .controlSize(.small)
                    }
                }
            } else if isDownloading {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 100)
                    HStack(spacing: 4) {
                        Text(model.variant)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 140)
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                Button("Download", action: onDownload)
                    .controlSize(.small)
                    .disabled(!canDownload)
            }
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
