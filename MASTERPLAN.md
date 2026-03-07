# MASTERPLAN — AIYO Wisper

## The Problem

macOS dictation is either locked behind paid subscriptions (Wispr Flow at $15/mo, SuperWhisper at $10/mo) or limited to Apple's built-in dictation which lacks smart formatting, context awareness, and command capabilities. Users who want high-quality voice-to-text with intelligent editing have no free, local-first, privacy-respecting option.

For developers, writers, and power users who spend hours typing, voice input could dramatically increase throughput — but existing solutions either send audio to the cloud (privacy concern), cost money monthly, or lack the polish to be a daily driver.

## The Vision

Users hold a hotkey, speak naturally, and perfectly formatted text appears wherever their cursor is — in any app, instantly. They can correct themselves mid-sentence, use voice commands to transform highlighted text, and trigger custom shortcuts — all processed locally on their Mac with zero cloud dependency. It feels like a native macOS feature that should have always existed.

## Who It's For

**Primary user:** Mac power users (developers, writers, knowledge workers) who type extensively and want to augment or replace keyboard input with voice.

- Comfortable with menubar apps and global hotkeys
- Value privacy and local processing
- Willing to trade some accuracy for zero subscription cost
- May use multiple languages or switch between them

**Out of scope:** Users who need medical/legal-grade transcription accuracy, real-time captioning, or mobile support.

## How It Works

1. **Install & Setup** — User downloads the app, grants microphone and accessibility permissions, and selects a Whisper model size
2. **Activate** — User holds a global hotkey (default: `fn`) from any app
3. **Speak** — A subtle visual indicator shows recording is active; user speaks naturally
4. **Release** — Audio is transcribed locally via Whisper.cpp, smart formatting is applied (punctuation, capitalization, course correction)
5. **Text appears** — Transcribed text is typed into the focused app via simulated keyboard input
6. **Command mode** — User activates a different hotkey to enter command mode, speaks an instruction about highlighted text (e.g., "make this more formal"), and the text is transformed in-place
7. **Voice shortcuts** — Custom trigger phrases expand to saved text snippets (e.g., "insert disclaimer" expands to a full paragraph)

## Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Language | Swift | Native macOS performance, direct access to system APIs |
| UI Framework | SwiftUI | Modern, declarative macOS UI with minimal boilerplate |
| Audio Capture | AVFoundation | Apple's native audio framework, reliable microphone access |
| Speech-to-Text | whisper.cpp | Best open-source local transcription, optimized for Apple Silicon |
| Text Injection | CGEvent / Accessibility API | Simulates keyboard input into any focused application |
| Smart Formatting | Local LLM or rule-based | Punctuation, capitalization, course correction |
| App Distribution | DMG / direct download | No App Store constraints on accessibility APIs |
| Build System | Xcode / Swift Package Manager | Standard macOS toolchain |

## Project Structure

```
aiyo-wisper/
├── MASTERPLAN.md
├── TODO.md
├── CLAUDE.md
├── AiyoWisper/
│   ├── AiyoWisperApp.swift          — App entry point
│   ├── Info.plist                    — Permissions declarations
│   ├── Assets.xcassets/              — App icon, menu bar icon
│   ├── Models/
│   │   ├── WhisperManager.swift      — whisper.cpp integration
│   │   ├── AudioRecorder.swift       — Microphone capture
│   │   ├── TextInjector.swift        — CGEvent keyboard simulation
│   │   ├── SmartFormatter.swift      — Post-processing pipeline
│   │   ├── CommandProcessor.swift    — Command mode logic
│   │   └── ShortcutManager.swift     — Voice shortcuts storage/matching
│   ├── Views/
│   │   ├── MenuBarView.swift         — Menu bar popover UI
│   │   ├── SettingsView.swift        — Preferences window
│   │   ├── RecordingIndicator.swift  — Floating recording indicator
│   │   └── OnboardingView.swift      — First-launch setup
│   ├── Services/
│   │   ├── HotkeyService.swift       — Global hotkey registration
│   │   ├── PermissionService.swift   — Permission checking/requesting
│   │   └── ModelManager.swift        — Whisper model download/selection
│   └── Utilities/
│       └── Constants.swift           — App-wide constants
├── WhisperCpp/                       — whisper.cpp as SPM dependency or vendored
├── Resources/
│   └── Models/                       — Downloaded Whisper models stored here
└── Tests/
    └── AiyoWisperTests/
```

## Phase 1 — Core Dictation

**Goal:** Users can hold a hotkey, speak, and see transcribed text appear in any app.

**What It Delivers:** A working menu bar app that captures audio while a hotkey is held, transcribes it locally via whisper.cpp, and types the result into the focused application.

**Core Features:**

- Menu bar app with start/stop control
- Global press-and-hold hotkey for recording (default: `fn`)
- Microphone audio capture via AVFoundation
- Local transcription via whisper.cpp (user-selectable model: tiny/base/small/medium/large)
- Text injection into focused app via CGEvent keyboard simulation
- Floating recording indicator (subtle overlay showing "recording...")
- First-launch onboarding: microphone permission, accessibility permission, model download
- Basic settings: hotkey configuration, model selection

**Out of Scope:**
- Smart formatting (Phase 2)
- Command mode (Phase 3)
- Voice shortcuts (Phase 3)
- Auto-language detection (Phase 2)

**Success Criteria:**
- Hold hotkey, speak a sentence, release — text appears in TextEdit within 2 seconds of release
- Works in Safari, VS Code, Slack, and Terminal
- App launches at login and lives in the menu bar
- Model download completes successfully for all sizes

## Phase 2 — Smart Formatting & Language Detection

**Goal:** Transcribed text reads like properly written prose, not raw speech output.

**What It Delivers:** Automatic punctuation, capitalization, filler word removal, course correction ("no wait, I mean..."), and auto-detection of spoken language.

**Core Features:**

- Punctuation insertion (periods, commas, question marks)
- Capitalization (sentence start, proper nouns)
- Filler word removal ("um", "uh", "like", "you know")
- Course correction — detects self-corrections and outputs only the final intent
- Auto-language detection via Whisper's built-in language ID
- Per-app formatting profiles (e.g., minimal formatting for code editors)

**Out of Scope:**
- Command mode (Phase 3)
- Voice shortcuts (Phase 3)
- Custom vocabulary/dictionary

**Success Criteria:**
- Dictated text includes correct punctuation without user saying "period" or "comma"
- Self-corrections ("I mean", "no wait", "actually") are cleaned up automatically
- Language switches between English and other Whisper-supported languages work without manual toggle

## Phase 3 — Command Mode & Voice Shortcuts

**Goal:** Users can transform text and trigger custom actions with their voice.

**What It Delivers:** A second hotkey activates command mode where spoken instructions modify highlighted text. Custom voice shortcuts expand trigger phrases to saved snippets.

**Core Features:**

- Command mode activation via separate hotkey
- Read highlighted text via Accessibility API
- Process voice command against highlighted text (e.g., "make this shorter", "fix grammar", "translate to Spanish")
- Replace highlighted text with processed result
- Voice shortcuts manager — create, edit, delete trigger/expansion pairs
- Shortcut matching during normal dictation (e.g., "insert email signature" expands inline)
- Settings UI for managing shortcuts

**Out of Scope:**
- Complex multi-step automations
- Integration with external AI APIs
- Shortcut sync across devices

**Success Criteria:**
- Highlight text in any app, activate command mode, say "make this more formal" — text is replaced
- Voice shortcut "insert disclaimer" expands to saved text in any app
- At least 10 custom shortcuts can be created and reliably triggered

## Future Vision

- **iOS companion app** — Same hotkey-driven UX adapted for iPhone/iPad with Shortcuts integration
- **Custom vocabulary** — User-defined words, acronyms, and names that improve transcription accuracy
- **Streaming transcription** — Show text as it's being spoken rather than after release
- **Plugin system** — Third-party actions for command mode (translate, summarize, format as markdown)
- **Whisper model fine-tuning** — Let users fine-tune on their own voice for better accuracy
- **Multi-modal input** — Combine voice with screenshot context for smarter command processing

## Constraints & Non-Negotiables

- **Local-only processing** — No audio or text ever leaves the device. This is a core product principle, not a compromise.
- **No subscription** — Free and open-source. No freemium, no usage limits.
- **macOS only** — No Electron, no cross-platform. Native Swift for the best OS integration.
- **Apple Silicon first** — Optimize for M-series chips. Intel support is nice-to-have, not required.
- **Minimal resource usage** — Must not noticeably impact battery or system performance during idle. Whisper inference should use GPU/ANE when available.
- **No App Store** — Accessibility API usage likely prevents App Store distribution. Distribute via DMG/GitHub releases.

## Success Metrics

| Metric | Phase 1 | Phase 2 | Phase 3 |
|--------|---------|---------|---------|
| Transcription latency (release to text) | < 3s (tiny), < 5s (large) | Same | Same |
| Transcription accuracy (English) | > 85% (model-dependent) | > 90% with formatting | Same |
| Text injection reliability | Works in 90% of apps | Same | Same |
| Memory usage (idle) | < 50 MB | < 60 MB | < 70 MB |
| Memory usage (recording) | < 300 MB (tiny), < 2 GB (large) | Same | Same |
| Crash-free sessions | > 95% | > 98% | > 99% |

## Open Decisions

- **Smart formatting engine:** Rule-based NLP vs. small local LLM (e.g., Llama 3 quantized)? Rule-based is faster and lighter but less capable. LLM handles course correction better but adds memory/latency.
- **Whisper.cpp integration method:** SPM package vs. vendored source vs. pre-built framework? Trade-offs between build complexity and update ease.
- **Text injection fallback:** CGEvent works for most apps but some (e.g., Electron apps with custom input handling) may need clipboard-paste fallback. Detect and switch automatically?
- **Recording indicator design:** Floating pill overlay (like Wispr) vs. menu bar animation vs. both?
- **Model storage location:** App bundle vs. Application Support directory? Models can be 75 MB to 3 GB.
- **Command mode LLM:** Which local model for text transformation? Needs to be small enough to run alongside Whisper.
