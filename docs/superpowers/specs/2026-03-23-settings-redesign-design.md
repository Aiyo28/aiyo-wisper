# Settings Redesign — Design Spec

## Problem

The settings window (480x380) overflows 9 tabs into a hidden `>>` menu. LLM configuration is limited to endpoint URL and model name text fields — no model picker, no generation parameters (temperature, repetition_penalty, frequency_penalty), causing the LLM repetition loop bug. Copy buttons in history provide no visual feedback.

## Solution

Consolidate 9 tabs into 5, widen the settings window, redesign Command Mode with auto-populated model picker and quality presets, add copy feedback across the app.

---

## Tab Structure

| # | Tab | Icon | Contents | Merges |
|---|-----|------|----------|--------|
| 1 | **General** | `gear` | Launch at login, text injection mode, **History section** (moved in) | + History |
| 2 | **Input** | `keyboard` | Dictation hotkey, command hotkey, shortcut trigger phrases (add/delete) | Hotkey + Shortcuts |
| 3 | **Formatting** | `textformat` | Language picker, auto-detect, minimal formatting toggle, **Dictionary section** (add/delete words) | Formatting + Dictionary |
| 4 | **Command Mode** | `command` | Enable toggle, Ollama connection, LLM model picker, quality presets, advanced sliders | Redesigned |
| 5 | **Transcription** | `cpu` | WhisperKit model download/select/delete (unchanged logic, renamed tab) | Models renamed |

**About** section: moved into General as a `Section("About")` at the bottom of the form — app icon, name, version, and tagline. No dedicated tab.

---

## Window Dimensions

- **Width**: 480 → **600** (all 5 tabs fit without overflow)
- **Height**: 380 → **480** (use `minHeight: 480` to allow resizing for tabs with longer content like Command Mode)
- System light/dark mode: automatic via SwiftUI native theming (no custom colors — use semantic colors like `.primary`, `.secondary`, `.tint`)

---

## Command Mode Tab — Detailed Design

### Section 1: Enable Toggle
Standard `Toggle("Enable command mode")` — persisted via `@AppStorage`.

### Section 2: LLM Server
- **Endpoint URL** — `TextField` with `.roundedBorder`, persisted to `AppStorage`
- **Connection status** — inline label:
  - Green: `● Connected` (Ollama responding)
  - Red: `● Not Running` (connection failed)
  - Grey: `● Unknown` (not yet tested)
- Auto-test on tab appearance and when endpoint changes (debounced — 800ms after last keystroke)

### Section 3: Model Picker

Populated by querying Ollama's `/api/tags` endpoint (returns list of locally pulled models). Falls back to manual text field if Ollama is unreachable.

Each model row shows:
- **Status dot**: green (active), blue (ready/downloaded), yellow pulse (downloading), grey (not pulled)
- **Model name** and **size**
- **Description** (from built-in registry, or "Custom model" for unknown ones)
- **Action button**:
  - Downloaded + not active → clickable row to select
  - Active → "Active" badge (green capsule)
  - Downloading → progress bar with percentage + cancel button
  - Not pulled → "Pull" button (triggers `ollama pull <model>`)

**Model registry** (built-in, stored in `Constants.LLM`):

| Model | Size | Description | Default Preset |
|-------|------|-------------|----------------|
| `llama3.2:3b` | 2.0 GB | Fast, good for simple commands | temp: 0.5, rep: 1.3, freq: 0.5, tokens: 1024 |
| `gemma3:4b` | 2.3 GB | Recommended for most tasks | temp: 0.5, rep: 1.1, freq: 0.3, tokens: 1024 |
| `phi-4-mini` | 2.2 GB | Strong reasoning | temp: 0.4, rep: 1.1, freq: 0.3, tokens: 1024 |
| `llama3.1:8b` | 4.7 GB | Best quality, slower | temp: 0.5, rep: 1.1, freq: 0.2, tokens: 2048 |
| `qwen2.5:7b` | 4.4 GB | Multilingual | temp: 0.5, rep: 1.1, freq: 0.3, tokens: 1024 |
| `mistral:7b` | 4.1 GB | Versatile all-rounder | temp: 0.5, rep: 1.1, freq: 0.3, tokens: 1024 |

Models not in the registry but present in Ollama appear as "Custom" with the Balanced preset defaults.

**Only downloaded models can be set as active.** Clicking a non-downloaded model does nothing — only the "Pull" button is interactive.

### Section 4: Quality Presets

Three-segment picker: **Fast** / **Balanced** (default) / **Accurate**

Each preset maps to parameter values that are model-aware (different models get different tuning):

| Preset | Temperature | Repetition Penalty | Frequency Penalty | Max Tokens | Use Case |
|--------|-------------|-------------------|-------------------|------------|----------|
| Fast | 0.2 | 1.0 | 0.0 | 512 | Quick commands, low latency |
| Balanced | per-model default | per-model default | per-model default | 1024 | General use (default) |
| Creative | 0.7 | 1.1 | 0.2 | 2048 | Longer/expressive output |

Selecting a preset updates the advanced sliders. If the user manually adjusts a slider, the preset indicator changes to "Custom".

### Section 5: Advanced (collapsed by default)

`DisclosureGroup("Advanced")` containing sliders:

| Slider | Range | Step | Labels |
|--------|-------|------|--------|
| Temperature | 0.0 – 1.0 | 0.1 | "Deterministic" ↔ "Creative" |
| Repetition Penalty | 1.0 – 2.0 | 0.1 | "Off (1.0)" ↔ "Strong (2.0)" |
| Frequency Penalty | 0.0 – 2.0 | 0.1 | "Off (0.0)" ↔ "Strong (2.0)" |
| Max Tokens | 256 – 4096 | 128 | numeric display |

"Reset to Preset Defaults" button at bottom.

All values persisted via `@AppStorage` with keys in `Constants.UserDefaultsKeys`.

---

## Ollama Integration — New Service

New file: `OllamaService.swift`

```
struct OllamaService: Sendable {
    let baseURL: String  // e.g. "http://localhost:11434"

    func listModels() async throws -> [OllamaModel]
    // GET /api/tags → parse name, size, modified_at

    func pullModel(name: String, onProgress: @Sendable (Double) -> Void) async throws
    // POST /api/pull with streaming JSON progress
    // Cancellation: caller wraps in a Task and calls task.cancel() to abort.
    // The method checks Task.isCancelled between stream chunks and throws CancellationError.

    func deleteModel(name: String) async throws
    // DELETE /api/delete — removes a pulled model from Ollama

    func isRunning() async -> Bool
    // GET /api/tags with short timeout, return true/false
}
```

**Derives Ollama base URL from LLM endpoint**: strips `/v1` suffix from `http://localhost:11434/v1` → `http://localhost:11434`.

**When Ollama is not installed:** If `isRunning()` returns false, the Model section shows an inline message: "Ollama is required for command mode. Download at ollama.ai" with a clickable link. The model list and presets are hidden until a connection is established.

**Pull failure handling:** If a pull fails mid-download (network drop, disk full, Ollama crash), the model row shows a red "Failed" status with the error message and a "Retry" button. The failed state clears when the user retries or navigates away.

**Endpoint change during pull:** Editing the endpoint while a pull is active shows a confirmation alert: "A model download is in progress. Changing the endpoint will cancel it." User can confirm (cancels pull, updates endpoint) or cancel (keeps current endpoint).

---

## LLMService Changes

### ChatCompletionRequest — add optional fields

```swift
struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
    let repeat_penalty: Double?        // NEW — Ollama extension (maps to repetition_penalty)
    let frequency_penalty: Double?     // NEW — standard OpenAI field
}
```

**Note on field naming:** Ollama's OpenAI-compatible endpoint accepts `repeat_penalty` (not `repetition_penalty`). The `frequency_penalty` field is standard OpenAI. Both are optional — omitted when set to their default values (1.0 and 0.0 respectively).

### LLMService.complete() — accept parameters

```swift
struct LLMParameters: Sendable {
    let temperature: Double
    let repeatPenalty: Double
    let frequencyPenalty: Double
    let maxTokens: Int
}

func complete(
    systemPrompt: String,
    userPrompt: String,
    parameters: LLMParameters
) async throws -> String
```

Remove hardcoded values. Parameters are passed explicitly at the call site — `CommandProcessor.process()` accepts `LLMParameters` as an argument. The caller (typically `DictationPipeline` or the view layer) constructs `LLMParameters` from `AppState` on the `@MainActor` and passes it to `CommandProcessor`. This avoids `CommandProcessor` needing `@MainActor` access to `AppState`.

---

## Copy Button Feedback

Both **Settings History** and **MenuBarView** copy buttons:

1. On tap: copy text to clipboard
2. Icon transitions: `doc.on.doc` → `checkmark` (green) via `.contentTransition(.symbolEffect(.replace))`
3. After 2 seconds: transition back to `doc.on.doc`
4. Use `@State private var copiedEntryId: UUID?` to track which entry shows the checkmark

---

## Constants Changes

```swift
enum UserDefaultsKeys {
    // Existing keys unchanged...
    static let llmTemperature = "llmTemperature"               // NEW
    static let llmRepetitionPenalty = "llmRepetitionPenalty"     // NEW
    static let llmFrequencyPenalty = "llmFrequencyPenalty"       // NEW
    static let llmMaxTokens = "llmMaxTokens"                    // NEW
    static let llmPreset = "llmPreset"                          // NEW
}

enum LLM {
    // Existing...
    static let modelRegistry: [LLMModelInfo] = [...]  // NEW — the 6 models above

    // Default values for @AppStorage (match Balanced preset for llama3.2:3b)
    static let defaultTemperature: Double = 0.5
    static let defaultRepeatPenalty: Double = 1.3
    static let defaultFrequencyPenalty: Double = 0.5
    static let defaultMaxTokens: Int = 1024
    static let defaultPreset: String = "balanced"
}
```

---

## Accessibility

- All interactive elements have `.accessibilityLabel` and `.accessibilityHint`
- Sliders announce current value and range
- Model status dots have text equivalents (e.g., `.accessibilityLabel("Downloaded")`)
- Copy feedback announced via `.accessibilityNotification(.announcement)`
- All colors use semantic SwiftUI tokens — automatic light/dark support
- No hardcoded colors anywhere in settings UI

---

## Files Changed

| File | Change |
|------|--------|
| `SettingsView.swift` | Restructure tabs (9→5), widen frame, merge History into General, merge Shortcuts into Input, merge Dictionary into Formatting, rename Models→Transcription, redesign Command Mode tab. Add `OllamaService` dependency — `CommandModeTab` creates it internally from the endpoint URL (no init injection needed). |
| `LLMService.swift` | Add `repetition_penalty`, `frequency_penalty` to request. Accept all params in `complete()`. |
| `Constants.swift` | Add `UserDefaultsKeys` for new LLM params. Add `LLM.modelRegistry`. |
| `CommandProcessor.swift` | Accept `LLMParameters` in `process()` instead of hardcoding. |
| `MenuBarView.swift` | Add copy feedback (checkmark transition). |
| **NEW** `OllamaService.swift` | Ollama API client — list models, pull with progress, health check. |
| **NEW** `LLMModelInfo.swift` | Model registry struct (name, size, description, default presets). |
| `AppState.swift` | Add `@AppStorage` properties for new LLM settings. Add computed `llmParameters: LLMParameters` property. |
| `DictationPipeline.swift` | Pass `appState.llmParameters` to `CommandProcessor.process()`. |

---

## Out of Scope

- Custom system prompt editing (future feature)
- Multiple Ollama server profiles
- WhisperKit model changes (Transcription tab keeps existing logic)
- Onboarding flow changes
