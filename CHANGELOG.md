# Changelog

All notable changes to AIYO Wisper.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

## [1.1.1] — 2026-05-21

### Fixed — LLM error classification (root cause of "Qwen3 keeps disappearing")

- **Runtime inference failures were misclassified as `modelCorrupted` and deleted the GGUF file.** Long-form dictation triggers context-overflow / decode failures in Qwen3-0.6B; `LocalLLMBackend.complete` mapped *every* non-cancellation error to `LLMError.modelCorrupted`, which the pipeline interprets as "the file is bad — delete it and disable cleanup." A single complex sentence was nuking a freshly downloaded model. Now: file/prewarm failures still throw `modelCorrupted`; runtime `respond()` failures throw `inferenceFailed(error)`, drop the session for a clean re-prewarm, and leave the GGUF on disk.
- **Cleanup timeout 5s → 30s.** Was covering prewarm (1-4s) plus generation in one budget; the first cleanup after launch almost always lost the race. Combined with the new eager prewarm, 30s is comfortable headroom for Qwen3-0.6B on multi-sentence input.
- **Eager prewarm on backend wire-up.** `LocalLLMBackend.prewarmInBackground()` is now kicked off as a detached utility task right after the backend is constructed (initial launch, post-download, model switch). The first cleanup call no longer pays llama.cpp's model-init cost against the cleanup timeout.

### Fixed — catalog mirror

- **Replaced broken Qwen 3 0.6B mirror.** `bartowski/Qwen3-0.6B-GGUF` returns HTTP 401 from HuggingFace — the repo doesn't exist (bartowski mirrors Qwen 2.5, not Qwen 3). Picking the mirror entry produced the user-facing "bad URL" error. Replaced with `lmstudio-community/Qwen3-0.6B-GGUF` (verified live, same exact filename `Qwen3-0.6B-Q4_K_M.gguf`).

### Fixed — stale model selection

- **Persisted `selectedLLMModelId` is normalized on launch.** If a previous build had a catalog entry id that's been removed (e.g. the bartowski mirror swap above), the old persisted id would leave no matching row in `states` — `isSelectedModelDownloaded` returned false, `download(modelId:)` no-op'd, and the picker looked permanently broken until the user manually clicked another row. The manager init now resolves the persisted id through the catalog and rewrites the UserDefaults value if it had drifted.

## [1.1.1-2026-05-20] — 2026-05-20

Fixes the two ship-blockers found in the v1.1.0 smoke test, plus a self-inflicted regression that turned every successful LLM download into a false "corrupted" verdict, plus a privacy hygiene pass on logging.

### Fixed — privacy

- **Removed user-text from runtime logs.** `DictationPipeline` and `TranscriptionEngine` were logging full transcripts, voice command text, the user's text selection, and Qwen3-cleaned output to the unified log on every dictation. AIYO Wisper's "audio never leaves your device" claim now extends to derived text — logs are metadata only (char counts, durations, model id, error type name).
- **LLM cleanup error logs** no longer interpolate the underlying error's payload, which can include echoed prompt fragments on some backends.

### Fixed — long-form transcription quality

- **Qwen3 cleanup was dropping whole sentences from long dictation.** The previous cleanup prompt explicitly allowed the model to "remove filler words / self-corrections / disfluencies" — Qwen3-0.6B interpreted that as a license to summarize, losing paragraph-length chunks. Prompt rewritten to bias toward punctuation/capitalization only, with explicit "preserve every word — do not remove, rephrase, or summarize" instruction. Applied across both `qwen3` and `generic` prompt families.
- **Cleanup length guard.** `SmartFormatter.isCleanupTruncated` discards the LLM's rewrite when its output is below 50 % of the input length — backstop against over-summarization the prompt change doesn't catch. Falls back to the regex-formatted text. Covered by `AiyoWisperTests/SmartFormatterCleanupTests.swift` (5 unit tests).
- **VAD energy threshold override.** WhisperKit's default `EnergyVAD(energyThreshold: 0.02)` is tuned for studio audio and classifies normal indoor speech pauses as silence — dropping VAD chunks of long dictation. We now pass `EnergyVAD(energyThreshold: 0.01)`.

### Fixed — LLM download validation (regression)

- **Every successful LLM download was being flagged as corrupt and deleted.** `LLMSession.DownloadModel.modelPath` from LocalLLMClient returns the *repo directory*, not the GGUF file. The validator was running `FileHandle(forReadingFrom:)` on a directory, which always returned no readable header → magic-byte check failed → file was treated as corrupt and the directory was deleted. Validation now reads the actual GGUF file path (`<directory>/<filename>`), and both `LLMModelManager` and `LocalLLMBackend` track the file URL explicitly.
- **Error wording.** Download failures now show the underlying error ("Download failed: …" with the real network message) and validation failures say "try again, or pick a different model below" instead of pointing back to the Settings tab the user is already on.

### Fixed — transcription

- **Long-form recordings returned empty text.** WhisperKit 1.0's `transcribe(audioArray:)` only chunks audio longer than the 30-second feature window when `DecodingOptions.chunkingStrategy == .vad`. We were passing `nil`, so anything past one window fell into the single-window path and silently returned an empty result. Now passing `.vad` so the VAD chunker activates for any utterance that needs it.
- **Result aggregation now falls back to per-segment text** when a chunk's top-level `result.text` is empty (segments still carry the actual transcription in some chunked paths).
- **Empty-transcribe is no longer silent.** Returning nothing now sets the error banner to "No speech detected — try speaking closer to the mic or for longer" so the user can tell the dictation flow actually ran.

### Fixed — AI cleanup model

- **Qwen3 download was failing partway with no fallback.** Single-mirror, single-model setup meant a flaky network on `unsloth/Qwen3-0.6B-GGUF` left the user stuck. Replaced the single hardcoded model with a picker (Settings → Formatting → AI Model) covering Qwen 3 0.6B / 1.7B, Llama 3.2 1B, Gemma 3 1B, a Qwen mirror via bartowski, and Phi 3.5 mini. Each entry has its own GGUF size floor for the corruption check.
- **System prompts assumed Qwen3 across the board.** `/no_think` is a Qwen3-only directive — Llama / Gemma / Phi would either ignore it or echo it. System prompts now branch on the selected model's `PromptFamily`, so non-Qwen models get a clean instruction prompt.
- **Backend: defense-in-depth strip of `<think>…</think>` blocks** in case `/no_think` is ignored by an older Qwen3 quantization.

### Added

- **Background auto-download of the LLM on launch** when the user has cleanup enabled but the selected model isn't on disk (fresh install, post-corruption recovery, picker switch). Non-blocking — dictation still works on the regex-only path while the download runs. Failure surfaces in Settings, never as a blocking modal.
- **Per-model download progress + error state** in the picker, so a partial download on one model doesn't hide that another one finished cleanly.

### Build / test hygiene

- **Pinned LocalLLMClient to a known-good revision** instead of tracking `main`, matching the SPM floating-dependency rule from the build audit.
- **Test target now uses the same C++ interop settings as the app target**, fixing the LocalLLMClientLlamaC `<memory>` import failure in `xcodebuild test`.
- **Replaced stale Ollama chat-completion tests** with coverage for the LocalLLMClient-era model catalog, prompt-family branching, and GGUF file-path validation.
- **Version metadata now lives in `project.yml`**, so `xcodegen generate` preserves `1.1.1 (3)` instead of resetting `Info.plist` to `1.0 (1)`.

## [1.1.0] — 2026-05-20

Reliability + security pass. Build green; runtime smoke test still pending.

### Fixed — security

- **DictationLearner could capture text from password / banking / unrelated-app fields** if the user switched focus during the 12-second observation window. Persisted captures to `dictionary_suggestions.json`. Now gates on (a) focused element unchanged, (b) role ∈ {`AXTextField`, `AXTextArea`, `AXComboBox`}, (c) explicit secure-text-field refusal via subrole + role-description.

### Fixed — concurrency / reliability

- **`usleep` on `@MainActor` injection paths** stalled the run loop and dropped pending hotkey events under heavy typing. `TextInjector.inject` / `readSelection` are now `async`, with `Task.sleep` replacing all `usleep` calls (200ms clipboard wait + per-character delays).
- **`HotkeyService` modifier-flag state** was mutated from NSEvent callbacks without synchronization. `@unchecked Sendable` was suppressing the warning without adding safety. Now lock-guarded via `OSAllocatedUnfairLock`; transitions computed under the lock, closures invoked outside.
- **`stopCommandRecordingAndProcess` could leave `isProcessing = true`** if any early-return path forgot to reset it. A 10-second force-reset workaround in `startRecording` was masking this. Replaced with a single `defer { isProcessing = false }`.
- **`DictationPipeline.start()` was not idempotent** — `OnboardingView` calls `onComplete?()` from both step-4 `.onAppear` and the Finish button, spawning duplicate `loadSelectedModel()` tasks racing on `isModelLoaded`. Added `hasStarted` guard.
- **`AiyoWisperApp.init` was not `@MainActor`**, constructing `@Observable` objects and calling MainActor methods from non-isolated context. Two `DispatchQueue.main.async` workarounds existed to escape the ambiguity. `init` is now `@MainActor`; workarounds dropped.

### Fixed — LLM cleanup

- **Partial GGUF downloads** passed `FileManager.fileExists` then crashed or hung `llama.cpp` on load — pipeline got stuck mid-transcription. Now validated by size (≥300 MB) + GGUF magic header before any load attempt. Corrupt files are auto-deleted and the LLM cleanup toggle is disabled until re-download.
- **`unsloth/Qwen3-0.6B-GGUF`** URL is still live and correct (verified on HuggingFace 2026-05-20); the "bad URL" symptom was the partial-download bug above, not the URL.
- **Hidden `/no_think` bug in command mode** — `CommandProcessor` had its own inline system prompt that was missing the `/no_think` directive Qwen3 requires. Every command-mode invocation was silently injecting Qwen3 reasoning tokens (`<think>...</think>`) into the user's selected text. `CommandProcessor` now references `Constants.LLM.commandSystemPrompt` (which has `/no_think`) as the single source of truth.

### Fixed — UI

- **Settings window opened behind other apps** when launched from the menu bar. `MenuBarExtra` + `SettingsLink` doesn't activate the app. Replaced with a button that calls `NSApp.activate` + raises the Settings window explicitly via `frameAutosaveName`.
- **Version string was hardcoded `"Version 0.1.0"`** in `SettingsView`. Now reads from `Bundle.main` `CFBundleShortVersionString`.
- **Onboarding "Cancel" download button was a disabled no-op.** Now wired to a real `ModelManager.cancelDownload()` via stored `Task`.

### Added

- **`DictationLearner`** — auto-learn dictionary suggestions from post-dictation edits. After each injection, the app reads the focused text field 12s later, diffs against what was typed at word level, and surfaces likely corrections (Levenshtein 1–3) as one-click "Suggested Corrections" in Settings → Formatting.

### Changed — build / deps

- **Migrated from `eastriverlee/LLM.swift` to `tattn/LocalLLMClient`** after the original repo was deleted from GitHub. Triggered a cascade:
  - Bumped `WhisperKit` 0.18 → 1.0 (older versions cap `swift-transformers` at 1.1.x; `LocalLLMClient` needs 1.3+ for its MLX backend).
  - `WhisperKit` 1.0 removed the public `Hub` module — `ModelManager.download` now uses `WhisperKit.download(variant:from:progress:)` (their vendored downloader).
  - Enabled C++ interop on the app target (`LocalLLMClientLlamaC` exposes C++ headers).
  - `LocalLLMBackend` became an `actor` (LocalLLMClient's session init is async).

### Known issues

- **Runtime path not manually re-tested after dependency migration.** Build is green, but the full dictation + LLM-cleanup + command-mode loop has not been exercised end-to-end. First launch should be treated as a smoke test.
- **Macros require `-skipMacroValidation` for CLI builds.** LocalLLMClient ships a Swift macro that needs first-launch approval in Xcode (one-time).

## [1.0.0] — earlier

Initial public release. Dictation, command mode, voice shortcuts, AI cleanup.
