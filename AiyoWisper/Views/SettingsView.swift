import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    let modelManager: ModelManager
    var onModelSelected: (() -> Void)?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralTab()
            }

            Tab("Hotkey", systemImage: "keyboard") {
                HotkeyTab()
            }

            Tab("Models", systemImage: "cpu") {
                ModelsTab(appState: appState, modelManager: modelManager, onModelSelected: onModelSelected)
            }

            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(width: 480, height: 320)
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
                    Text("Record hotkey")
                    Spacer()
                    Text("Control (hold)")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .formStyle(.grouped)
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
                                    try? modelManager.deleteModel(model.id)
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
