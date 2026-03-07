import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let modelManager: ModelManager

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

            if !appState.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.lastTranscription)
                        .font(.body)
                        .lineLimit(3)
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

            if let error = appState.errorMessage {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle: .green
        case .recording: .red
        case .transcribing: .orange
        case .injecting: .blue
        case .error: .red
        }
    }

    private var statusText: String {
        switch appState.status {
        case .idle: "Ready"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .injecting: "Injecting text..."
        case .error: "Error"
        }
    }
}
