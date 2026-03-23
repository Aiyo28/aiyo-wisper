# AIYO Wisper — Agent Protocol

## Context

macOS menu bar voice-to-text app. Hold hotkey → speak → text appears at cursor. Local-only via WhisperKit.

| Component | Stack | Constraints |
|-----------|-------|-------------|
| App | Swift 6, SwiftUI, macOS 15+ | ARM64 only. No App Sandbox (Accessibility API). |
| STT | WhisperKit (CoreML/Neural Engine) | Models in `~/Library/Application Support/AiyoWisper/Models/` |
| Text inject | CGEvent `keyboardSetUnicodeString` | Clipboard fallback for terminals |
| Build | XcodeGen (`project.yml`) | Regenerate: `xcodegen generate` |
| Distribution | DMG / GitHub releases | No App Store (Accessibility prevents it) |

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
9. **Audio format:** 16kHz mono Float32 — WhisperKit requires this exact format.
10. **MenuBarExtra lifecycle:** No `WindowGroup` — app lifecycle via `MenuBarExtra` only.

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

- Smart formatting engine: rule-based NLP vs. small local LLM (Phase 2)
- Command mode LLM selection (Phase 3)
