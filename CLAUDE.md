# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AIYO Wisper is a native macOS menu bar app for voice-to-text dictation. Users hold a global hotkey (Control), speak, and transcribed text appears wherever their cursor is — processed entirely locally via WhisperKit. Free, open-source, no cloud dependency.

## Tech Stack

- **Language:** Swift 6 with strict concurrency (macOS 15.0+, Apple Silicon only)
- **UI:** SwiftUI with `MenuBarExtra` lifecycle (no `WindowGroup`)
- **Speech-to-Text:** WhisperKit (pure Swift/CoreML, Neural Engine acceleration)
- **Audio:** AVAudioEngine for microphone capture (16kHz mono Float32)
- **Text Injection:** CGEvent `keyboardSetUnicodeString` (clipboard-paste fallback for terminals)
- **Build:** XcodeGen project (`project.yml` → `AiyoWisper.xcodeproj`)
- **Distribution:** DMG / GitHub releases (no App Store — Accessibility API prevents it)

## Build & Run

```bash
# Regenerate Xcode project (after modifying project.yml)
xcodegen generate   # or: /tmp/xcodegen/xcodegen/bin/xcodegen generate

# Open in Xcode
open AiyoWisper.xcodeproj

# Build from CLI
xcodebuild -project AiyoWisper.xcodeproj -scheme AiyoWisper -destination "platform=macOS,arch=arm64" build
```

Build and run via Xcode (Cmd+R). The app requires:
- **Microphone permission** — for audio capture
- **Accessibility permission** — for global hotkey registration and text injection via CGEvent

## Architecture

The app follows a layered architecture with clear separation:

- **Models/** — Core business logic: `WhisperManager` (WhisperKit wrapper), `TranscriptionEngine` (model load + transcribe), `AudioRecorder` (AVAudioEngine capture to 16kHz mono f32), `TextInjector` (CGEvent keyboard simulation), `DictationPipeline` (orchestrator), `SmartFormatter` (Phase 2), `CommandProcessor` (Phase 3), `ShortcutManager` (Phase 3)
- **Views/** — SwiftUI views: `MenuBarView` (popover), `SettingsView` (preferences), `RecordingIndicator` (floating pill overlay), `OnboardingView` (first-launch permissions + model download)
- **Services/** — System integration: `HotkeyService` (global hotkey registration), `PermissionService` (mic + accessibility permission flow), `ModelManager` (Whisper model download/selection/storage in Application Support)
- **Utilities/** — Shared constants

### Key Data Flow

1. `HotkeyService` detects Control key-down → `AudioRecorder` starts capturing (AVAudioEngine tap)
2. Control key-up → `AudioRecorder` stops → `[Float]` samples passed to `TranscriptionEngine`
3. `TranscriptionEngine` runs WhisperKit inference (CoreML/Neural Engine) → raw text
4. `TextInjector` types result into focused app via CGEvent (or clipboard fallback for terminals)

### Command Mode (Phase 3)

Separate hotkey → record voice command → read highlighted text via Accessibility API → transform with local LLM → replace highlighted text.

## Development Phases

The project is built in 3 phases (see MASTERPLAN.md for full details):
1. **Core Dictation** — hotkey, recording, transcription, text injection (current phase)
2. **Smart Formatting** — punctuation, capitalization, filler removal, language detection
3. **Command Mode & Voice Shortcuts** — text transformation, trigger phrase expansion

## Key Constraints

- **Local-only processing** — no audio or text ever leaves the device
- **Whisper models** stored in `~/Library/Application Support/AiyoWisper/Models/`, sizes range from 75 MB (tiny) to 3 GB (large)
- **Whisper inference** should use GPU/Neural Engine when available
- **Idle memory** must stay under 50 MB
- **Transcription latency target:** < 3s for tiny model, < 5s for large model

## Decisions Made

- **WhisperKit** over whisper.cpp — pure Swift/CoreML, Neural Engine acceleration, built-in model download, no C++ bridging
- **Hold Control key** to record — standard modifier key, detected via `NSEvent.addGlobalMonitorForEvents(.flagsChanged)`
- **SMAppService** for launch-at-login — native macOS API, no third-party dependency
- **No App Sandbox** — required for Accessibility API (CGEvent, AXIsProcessTrusted)

## Open Decisions

- Smart formatting engine: rule-based NLP vs. small local LLM (Phase 2)
- Command mode LLM selection (Phase 3)
