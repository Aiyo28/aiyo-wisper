# TODO — AIYO Wisper

## Phase 1 — Core Dictation

### Setup & Infrastructure
- [x] Create Xcode project with SwiftUI lifecycle and menu bar app target
- [x] Configure Info.plist for microphone and accessibility permissions
- [x] Add WhisperKit as Swift Package Manager dependency
- [x] Set up app signing for distribution outside App Store
- [ ] Create app icon and menu bar icon assets
- [x] Configure launch-at-login capability

### Audio Recording
- [x] Implement AudioRecorder class using AVFoundation for microphone capture
- [x] Handle microphone permission request and denial gracefully
- [x] Record audio in Whisper-compatible format (16kHz, mono, f32) with AVAudioConverter
- [x] Add recording state management (idle, recording, processing)

### Whisper Integration
- [x] Implement TranscriptionEngine wrapper around WhisperKit
- [x] Add model download functionality with progress indicator
- [x] Support model selection (tiny, base, small, medium, large)
- [x] Store models in Application Support directory
- [x] Implement transcription pipeline: audio samples to text
- [x] Run inference on background thread to avoid UI blocking

### Text Injection
- [x] Implement TextInjector using CGEvent to simulate keyboard input
- [x] Handle Accessibility API permission request and checking
- [x] Support Unicode characters via keyboardSetUnicodeString (chunked)
- [x] Add clipboard-paste fallback for terminal apps
- [ ] Test injection across Safari, VS Code, Slack, Terminal, TextEdit

### Global Hotkey
- [x] Implement HotkeyService for global press-and-hold hotkey registration
- [x] Default hotkey: Control key (hold to record, release to transcribe)
- [x] Detect key-down to start recording, key-up to stop and transcribe
- [x] Ignore hotkey when other modifiers held (Cmd+C won't trigger)

### Recording Indicator
- [x] Create floating NSPanel overlay showing recording state
- [x] Position at top-center of screen
- [x] Show visual feedback: pulse animation for recording, spinner for transcribing
- [x] Dismiss automatically when returning to idle

### Menu Bar UI
- [x] Create MenuBarView with popover showing app status
- [x] Add quick controls: model info, recording status, last transcription
- [x] Add "Quit" and "Settings..." menu items
- [x] Menu bar icon changes based on status (mic.fill when recording)

### Settings
- [x] Create SettingsView with tabbed preferences window
- [x] Hotkey display (Control hold)
- [x] Model selection with download/delete controls
- [x] Launch at login toggle via SMAppService
- [x] About tab with version info

### Onboarding
- [x] Create OnboardingView for first-launch setup flow
- [x] Step 1: Welcome and app description
- [x] Step 2: Request microphone permission
- [x] Step 3: Request accessibility permission with polling
- [x] Step 4: Select and download Whisper model
- [x] Step 5: Ready to go confirmation

### Edge Cases
- [x] Minimum recording duration guard (< 0.3s ignored)
- [x] Permission checks before recording (mic + accessibility)
- [x] Error auto-reset after 3 seconds
- [x] Empty transcription guard
- [x] Terminal auto-detect for clipboard fallback
- [ ] Test long recordings (30s+)
- [ ] Test rapid press-release behavior

## Phase 2 — Smart Formatting & Language Detection

### Smart Formatting Engine
- [ ] Implement SmartFormatter post-processing pipeline
- [ ] Add punctuation insertion (periods, commas, question marks, exclamation marks)
- [ ] Add sentence-start capitalization
- [ ] Add filler word removal ("um", "uh", "like", "you know", "basically")
- [ ] Implement course correction detection and cleanup
- [ ] Research and decide: rule-based vs. local LLM approach

### Language Detection
- [ ] Enable Whisper's built-in language detection
- [ ] Display detected language in recording indicator
- [ ] Support auto-switching between languages without manual toggle

### Per-App Profiles
- [ ] Detect focused application bundle ID
- [ ] Create default formatting profiles (prose, code, chat)
- [ ] Allow user to assign profiles to specific apps
- [ ] Minimal formatting mode for code editors (no auto-punctuation)

## Phase 3 — Command Mode & Voice Shortcuts

### Command Mode
- [ ] Implement CommandProcessor for voice-driven text transformation
- [ ] Register separate global hotkey for command mode activation
- [ ] Read highlighted/selected text via Accessibility API
- [ ] Integrate local LLM for text transformation (research model options)
- [ ] Replace highlighted text with processed result
- [ ] Support commands: "make shorter", "make formal", "fix grammar", "translate to [language]"

### Voice Shortcuts
- [ ] Implement ShortcutManager for trigger/expansion pairs
- [ ] Create settings UI for creating, editing, and deleting shortcuts
- [ ] Match trigger phrases during normal dictation flow
- [ ] Expand matched shortcuts inline before text injection
- [ ] Persist shortcuts to disk (JSON or UserDefaults)
