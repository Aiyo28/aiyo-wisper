# AIYO Wisper — Agent Protocol

## Context

macOS menu bar voice-to-text app. Hold hotkey → speak → text appears at cursor. Local-only, on-device.

| Component | Stack | Constraints |
|-----------|-------|-------------|
| App | Swift 6, SwiftUI (Liquid Glass), macOS 26+ | ARM64 only. No App Sandbox (Accessibility API). |
| STT | Apple `SpeechAnalyzer` (default) · WhisperKit (optional) | Both conform to `TranscriptionProviding`. Apple = system-managed locale assets; WhisperKit models in `~/Library/Application Support/AiyoWisper/Models/`. |
| Formatting | Apple Foundation Models (on-device LLM) → rule-based fallback | `AIFormatter`; always fails soft to `SmartFormatter`. |
| Text inject | CGEvent `keyboardSetUnicodeString` | Clipboard fallback for terminals |
| Build | XcodeGen (`project.yml`) | Regenerate: `xcodegen generate` |
| Distribution | DMG / GitHub releases | No App Store (Accessibility prevents it) |
| Repo type | **OSS** (public) | Planning docs in vault only, never committed |

## Repo Hygiene

MASTERPLAN.md, TODO.md, NEXT.md, session logs, and decision docs live in Knowledge OS vault (`Projects/aiyo-wisper/`). They are gitignored. Contributor-facing roadmap goes in README.md.

## Session Protocol

1. **Start:** Read `NEXT.md` (session continuity) + `docs/_context/BRIEF.md` (L1 context, when created)
2. **Fallback (until BRIEF.md exists):** Read `Projects/aiyo-wisper/MASTERPLAN.md` from vault
3. **Check:** Read TODO from vault if task work planned
4. **End:** `session-complete` skill auto-runs

## Where to Find Things

| Topic | Location |
|-------|----------|
| Masterplan + phases | Vault: `Projects/aiyo-wisper/MASTERPLAN.md` |
| TODO | Vault: `Projects/aiyo-wisper/TODO.md` |
| Session log + decisions | Vault: `Projects/aiyo-wisper/sessions/` |
| Implementation plans | Vault: `Projects/aiyo-wisper/plans/` |

## Rules

- **Local-only:** No audio or text ever leaves the device.
- **TDD:** Vertical slices. Swift Testing (`@Test`, `#expect`).
- **Idle memory:** Must stay under 50 MB.
- **Latency:** < 3s (tiny model), < 5s (large model).

## Critical Gotchas

1. **Strict concurrency:** `SWIFT_STRICT_CONCURRENCY = complete`. All `@MainActor` boundaries explicit.
2. **XcodeGen:** Run `xcodegen generate` after any `project.yml` change.
3. **Entitlements:** `com.apple.security.device.audio-input` + no sandbox. Hardened runtime ON.
4. **TCC permissions:** App needs BOTH Accessibility AND Input Monitoring. After `tccutil reset`, re-grant manually.
5. **Input Monitoring:** Separate from Accessibility — required for global keystroke detection.
6. **Clipboard guard:** `TextInjector` falls back to clipboard paste for terminals. Must restore original clipboard.
7. **`@MainActor` isolation:** Views + any UI-touching code. `WhisperManager` is `@MainActor`.
8. **Model IDs:** WhisperKit model names must match HuggingFace repo naming exactly.
9. **Audio format:** 16kHz mono Float32 — `AudioRecorder` output. WhisperKit consumes it directly; `AppleSpeechEngine` writes a temp WAV and lets `SpeechAnalyzer.analyzeSequence(from:)` convert internally.
10. **MenuBarExtra lifecycle:** No `WindowGroup` — app lifecycle via `MenuBarExtra` only.
11. **Apple Speech is locale-pinned.** `SpeechTranscriber(locale:)` transcribes ONE language — this is the fix for language bleed, not a limitation to work around. "Auto-detect" applies to WhisperKit only. Changing preferred language must re-call `prepareEngine()`.
12. **`AssetInventory` reserve limit.** The Apple engine downloads + reserves a locale on first use. `reservedLocales`/`supportedLocales`/`installedLocales` are `async` getters; `reservedLocales` too.
13. **Foundation Models is optional at runtime.** `AIFormatter.isAvailable` gates on Apple Intelligence being enabled + eligible hardware. Never assume it's present — the rule-based path must always work.
14. **New-API signatures drift beta→GA.** Verify against the installed SDK's `.swiftinterface` (e.g. `SpeechTranscriber.Preset.transcription`, not the beta `.offlineTranscription`) rather than trusting WWDC-era sample code.

## Build & Run

```bash
xcodegen generate
open AiyoWisper.xcodeproj   # Build via Xcode (Cmd+R)
```

Requires: Microphone + Accessibility permissions in System Settings.

## Effort Calibration

| Level | Scope | Response | Subagents |
|-------|-------|----------|-----------|
| TRIVIAL | 1 file, obvious | Act. No preamble. | `haiku` |
| STANDARD | Clear spec, 2-4 files | Milestones only. | `sonnet` |
| COMPLEX | Architectural, tradeoffs | Think first. 1 question max. | `opus` |
| DEEP | Security, perf, novel | Full depth. Suggest opus if not already. | `opus` |

**Act** when unambiguous. **Ask** only for destructive actions or genuine ambiguity.

## Anti-Loop

Same error 3x → **STOP**. Verify with user. Write happy path only (<20 lines).

## Open Decisions

- ~~Smart formatting engine: rule-based NLP vs. small local LLM~~ → **Resolved (v1.2.0):** Apple Foundation Models on-device LLM, with rule-based fallback.
- **Command mode** (e.g. "make this a bullet list") — not yet built. Now cleanly doable via `AIFormatter` + a `@Generable` command schema on Foundation Models. Candidate for v1.3.
- **Streaming transcription** — v1.2 uses batch (transcribe-on-release). `SpeechAnalyzer` also supports live streaming for near-zero post-release latency; candidate enhancement.
