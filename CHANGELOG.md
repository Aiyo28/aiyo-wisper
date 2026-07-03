# Changelog

All notable changes to AIYO Wisper.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

## [1.2.4] — 2026-07-03

### Changed

- **Language options are now dynamic per engine.** The Apple engine offers only the languages it can actually serve on this OS (queried live from `SpeechTranscriber.supportedLocales`) — English today — and **the list expands automatically as macOS adds locales** (Russian will appear the moment Apple ships it, no update needed). WhisperKit keeps offering everything (it's multilingual). `AppState.appleSupportedLanguages` drives both the menu-bar and Settings pickers.
- **Auto now spans exactly the supported set.** With only English supported, Auto is a single fast pass (no dual-pass cost); it becomes multi-pass automatically once a second language is available.
- **Pinned-but-unavailable language falls back to Auto** instead of erroring, so switching engines or OS versions never leaves the app stuck.

## [1.2.3] — 2026-07-03

### Fixed

- **Selecting a language Apple doesn't support no longer breaks the whole engine.** `AppleSpeechEngine.prepare` now skips unsupported locales and continues with the rest, instead of throwing on the first one — so Auto (en + ru) keeps English working even though Russian is unavailable, rather than failing outright. Only when *every* requested language is unsupported does it error and route to WhisperKit.
- **Accurate messaging.** The setup error no longer implies an OS-settings fix; it correctly states the language is absent from Apple's on-device catalog on this macOS and points to the WhisperKit engine.

### Notes

- **Verified on this Mac (macOS 27 beta): Apple's `SpeechTranscriber` supports 45 locales — English ×9, German, Spanish, French, Italian, Portuguese, Chinese, Japanese, Korean, Hindi + Indic languages, `mul-IN` — but NOT Russian.** For Russian (and EN↔RU bilingual use), the **WhisperKit engine** is the path — its multilingual models include Russian. Apple engine = best for English; WhisperKit = the bilingual option until Apple ships `ru`.

## [1.2.2] — 2026-07-03

### Added

- **Automatic EN↔RU language detection for the Apple engine.** Set Language → Auto (menu bar or Settings → Formatting) and each clip is transcribed once per configured language; the pass with the highest average acoustic confidence (`SpeechAttributes.transcriptionConfidence`) wins. Apple's API has no spoken-language detector and EN/RU differ only by script — so confidence is the honest signal. NaturalLanguage (`NLLanguageRecognizer`) is a fallback when confidence doesn't populate. Fixes Russian speech being force-decoded as English/French gibberish. (`AppleSpeechEngine`)
- **"Auto" option in the menu-bar language picker.**

### Notes

- Auto mode ~doubles per-utterance compute (one pass per language) — opt-in; pin a single language for maximum speed. Best-effort, not perfect; the manual toggle remains the reliable path.

## [1.2.1] — 2026-07-03

Accuracy pass for the Apple engine, aimed at bilingual/technical dictation.

### Added

- **Custom vocabulary biasing for the Apple engine.** The user's dictionary terms (`DictionaryManager.vocabularyWords`, grown automatically by `DictationLearner` from post-dictation edits) are now fed to `SpeechAnalyzer` as `AnalysisContext.contextualStrings` before each utterance, so names, jargon, and domain terms transcribe correctly instead of being guessed as common words. Capped at 100 terms. Previously the Apple engine ignored the vocabulary entirely. (`AppleSpeechEngine`)
- **Menu-bar language toggle.** The menu bar now has an inline language picker (EN/RU) that pins the transcriber's locale and re-prepares the engine on the spot — no Settings trip for a bilingual user switching languages.

### Notes

- **Multilingual auto-detect deferred.** Apple's `SpeechTranscriber` is locale-pinned on the macOS 26.5 SDK — there's no auto-detect surface — so the language toggle is the answer until the Xcode 27 SDK is installable. Tracked in `CLAUDE.md` → Open Decisions.

## [1.2.0] — 2026-07-02

Native macOS 26 rebuild. AIYO Wisper now uses Apple's on-device speech and language models as its defaults, restoring AI text cleanup — this time without a fragile third-party LLM stack. Minimum OS is now macOS 26.0 (Tahoe).

### Added

- **Apple `SpeechAnalyzer` / `SpeechTranscriber` engine (new default).** On-device speech recognition with no app-managed model download — the locale model is system-provided and shared. The transcriber is pinned to your chosen language, which structurally fixes the WhisperKit language-mixing bug (English speech no longer picks up stray Chinese/other-language characters). Lower latency, tuned for the Neural Engine. Locale assets install and reserve automatically on first use via `AssetInventory`. (`AppleSpeechEngine`)
- **AI Formatting via Apple Foundation Models.** Transcripts are cleaned up by the on-device system LLM — punctuation, capitalization, filler and false-start removal — running entirely on your Mac. This is the native successor to the Qwen3/LLM.swift stack removed in 1.1.1, with none of the download or crash baggage. Every path fails soft to the rule-based formatter when the model is off, unavailable, or declines the input. A minimal instruction set preserves verbatim text in code editors and terminals. (`AIFormatter`)
- **Speech-engine picker.** Settings → Transcription lets you switch between the Apple engine and WhisperKit; WhisperKit model downloads only appear when that engine is selected.
- **Liquid Glass recording overlay.** The floating dictation pill is now a genuine glass capsule that refracts the desktop behind it, tinted red on error.

### Changed

- **Minimum macOS raised to 26.0.** The app is built against the macOS 26 SDK to adopt `SpeechAnalyzer`, Foundation Models, and Liquid Glass.
- **Transcription is now pluggable.** `TranscriptionEngine` (WhisperKit) and `AppleSpeechEngine` both conform to a new `TranscriptionProviding` protocol; the pipeline swaps between them behind one call site and unloads the inactive engine to respect the < 50 MB idle-memory budget.
- **Language changes apply immediately.** Switching your preferred language re-prepares the locale-pinned Apple engine on the spot instead of waiting for a relaunch.
- **`NSSpeechRecognitionUsageDescription`** added to Info.plist for the Speech framework.

### Notes

- WhisperKit remains fully supported as an opt-in engine for users who need a specific Whisper model or a locale Apple doesn't ship on-device.

## [1.1.1] — 2026-05-23

Major release: AI text cleanup feature removed. Whisper rejection policy rewritten around the principle "some transcript is better than breaking the flow of dictation."

### Removed

- **AI text cleanup (Qwen3 / LocalLLMClient / command mode).** The entire LLM stack — `CommandProcessor`, `LLMParameters`, `LLMBackend`, `LocalLLMBackend`, `LLMModelManager`, the model picker, the command-mode hotkey, all related Settings UI — is gone. Reason: the integration required a llama.cpp Metal-teardown workaround for a `GGML_ASSERT` crash that fired on every app quit, and the cleanup pass never delivered enough quality lift to justify that fragility. The smart-formatter regex passes remain.
- **LocalLLMClient SPM dependency and C++ interop build flags** (`SWIFT_OBJC_INTEROP_MODE: objcxx`, `-cxx-interoperability-mode=default`). First clean build is now significantly faster.

### Changed

- **Whisper decoding policy: three of four confidence gates disabled.** `noSpeechThreshold`, `logProbThreshold`, and `firstTokenLogProbThreshold` are now `nil`. Default WhisperKit settings were rejecting legitimate quiet English speech and producing 62-char structural-token-only output. `compressionRatioThreshold: 2.4` is the sole guard, keeping the repetition-hallucination check (e.g. "Hello, hello, hello") intact.
- **Empty transcript no longer surfaces a red error banner.** When Whisper returns nothing (silence, decode rejection, leaked-only structural tokens), the pipeline now returns silently to `.idle`. The hotkey is immediately available for retry. Failure is still logged via `os.Logger` for diagnosis.
- **Auto-update is opt-in.** `SUEnableAutomaticChecks` defaults to `false`; check the toggle in Settings → Updates to enable. "Check Now" button always works.
- **Recommended model is now Turbo (large-v3-turbo, 632 MB).** Without the AI cleanup polish, raw Whisper accuracy matters more — Turbo is the right default for most users. The Small model (216 MB) is kept in the catalog as the balanced multilingual option, re-labeled accordingly.
- **English Turbo warning generalized.** The English-only model's warning previously named Russian specifically ("won't work with Russian"); it now reads "will not transcribe other languages, and won't work with auto-detect" — accurate for any non-English input. Model description updated to match.
- **README scrubbed of removed features.** Dropped the AI Cleanup, Command Mode, and Qwen3 sections (and the competitive-table rows that referenced them) now that the LLM stack is gone, so the public docs match the shipped app.
- **Print statements replaced with `os.Logger`** across pipeline, transcribe, hotkey, learner, dictionary, and appstate. Diagnostics surface in Console.app under `subsystem:com.aiyo.wisper`, regardless of how the app was launched.

### Added

- **Special-token strip backstop.** WhisperKit's tokenizer sometimes leaks raw structural tokens (`<|startoftranscript|>`, `<|de|>`, `<|0.00|>`, `<|endoftext|>`) into segment text on temperature-fallback paths. A regex pass in `TranscriptionEngine` removes them before injection. Covered by `SpecialTokenStripTests`.
- **Short-clip language fallback.** Whisper's language head is unreliable on short audio and was returning `<|de|>` for English speech under 3 seconds. Clips shorter than 3s now force `language: "en"` when auto-detect is on; longer clips keep auto-detect.
- **Model identifier transparency.** Onboarding and Settings now show the technical model id in brackets next to the friendly name (e.g. `Turbo [large-v3-turbo]`). Download progress shows the full WhisperKit variant string (`openai_whisper-large-v3-v20240930_turbo_632MB`) with percentage.

### Fixed

- **Crash on first-launch onboarding path.** `NSApp.activate(ignoringOtherApps:)` was being called inside SwiftUI `App.init()`, where `NSApp` is `nil` until AppKit finishes bootstrapping. Force-unwrap crashed any install with empty UserDefaults. Activation now deferred to the next runloop tick via `DispatchQueue.main.async`.
- **PII in logs.** `DictationPipeline.loadSelectedModel` was logging the full model path (`/Users/<username>/Library/Application Support/AiyoWisper/Models/...`) at `.public` privacy, leaking the username into Console.app captures. Path dropped from the log line; model name retained.
- **AX force-cast.** `DictationLearner.focusedElement` force-cast `CFTypeRef` → `AXUIElement` without a type check. Now guarded by `CFGetTypeID(raw) == AXUIElementGetTypeID()`, returning `nil` if the bridge ever changes.

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
