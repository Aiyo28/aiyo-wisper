# TODO — AIYO Wisper

## Phase 1 — Core Dictation

### Setup & Infrastructure
- [ ] Create Xcode project with SwiftUI lifecycle and menu bar app target
- [ ] Configure Info.plist for microphone and accessibility permissions
- [ ] Add whisper.cpp as Swift Package Manager dependency
- [ ] Set up app signing for distribution outside App Store
- [ ] Create app icon and menu bar icon assets
- [ ] Configure launch-at-login capability

### Audio Recording
- [ ] Implement AudioRecorder class using AVFoundation for microphone capture
- [ ] Handle microphone permission request and denial gracefully
- [ ] Record audio to temporary file in Whisper-compatible format (16kHz, mono, f32)
- [ ] Add recording state management (idle, recording, processing)

### Whisper Integration
- [ ] Implement WhisperManager wrapper around whisper.cpp C API
- [ ] Add model download functionality with progress indicator
- [ ] Support model selection (tiny, base, small, medium, large)
- [ ] Store models in Application Support directory
- [ ] Implement transcription pipeline: audio file to text
- [ ] Run inference on background thread to avoid UI blocking

### Text Injection
- [ ] Implement TextInjector using CGEvent to simulate keyboard input
- [ ] Handle Accessibility API permission request and checking
- [ ] Support Unicode characters and special characters
- [ ] Add clipboard-paste fallback for apps that reject CGEvent input
- [ ] Test injection across Safari, VS Code, Slack, Terminal, TextEdit

### Global Hotkey
- [ ] Implement HotkeyService for global press-and-hold hotkey registration
- [ ] Default hotkey: fn key (with option to customize)
- [ ] Detect key-down to start recording, key-up to stop and transcribe
- [ ] Prevent hotkey from triggering the focused app's own shortcuts

### Recording Indicator
- [ ] Create floating pill overlay showing recording state
- [ ] Position near cursor or screen corner (configurable)
- [ ] Show visual feedback: recording animation, processing spinner
- [ ] Dismiss automatically after text injection completes

### Menu Bar UI
- [ ] Create MenuBarView with popover showing app status
- [ ] Add quick controls: enable/disable, current model, recording status
- [ ] Add "Quit" and "Settings" menu items

### Settings
- [ ] Create SettingsView with tabbed preferences window
- [ ] Hotkey configuration with key capture UI
- [ ] Model selection with download/delete controls
- [ ] Launch at login toggle
- [ ] Recording indicator position preference

### Onboarding
- [ ] Create OnboardingView for first-launch setup flow
- [ ] Step 1: Welcome and app description
- [ ] Step 2: Request microphone permission
- [ ] Step 3: Request accessibility permission with system instructions
- [ ] Step 4: Select and download Whisper model
- [ ] Step 5: Test dictation with guided walkthrough

#### Done — Phase 1
_(none yet)_

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

#### Done — Phase 2
_(none yet)_

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

#### Done — Phase 3
_(none yet)_
