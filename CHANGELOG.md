# Changelog

All notable changes to AIYO Wisper.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

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
