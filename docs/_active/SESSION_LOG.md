# Session Log

### 2026-03-07 — Phase 1 implementation complete, all code pushed to master

**Changed files:** AiyoWisper/Models/DictationPipeline.swift, TODO.md, project.yml, and full app skeleton (Models/, Views/, Services/, Utilities/)

- **What changed:** Implemented the entire Phase 1 Xcode project with WhisperKit integration, all placeholder files (AudioRecorder, TranscriptionEngine, TextInjector, HotkeyService, PermissionService, ModelManager, all views), MenuBarExtra app entry point, onboarding wizard, settings, and recording indicator. Fixed entitlements build error. Added accessibility permission guard to DictationPipeline. Updated TODO.md to reflect completed items. Created swift-development skill at ~/.claude/skills/swift-development/ with SKILL.md + 8 reference files. All 5 commits pushed to remote master.
- **Decisions made:** WhisperKit over whisper.cpp, XcodeGen for project gen, Control key as hotkey, SMAppService for login, no sandbox, entitlements excluded from sources
- **Issues resolved:** Entitlements "modified during build" error (excluded *.entitlements from sources in project.yml)
- **New issues found:** None
- **Next up:** Test actual dictation flow end-to-end, create app icons, test text injection across apps

### 2026-03-07 — Project kickoff: MASTERPLAN.md and TODO.md created

**Changed files:** MASTERPLAN.md, TODO.md, docs/_active/SESSION_LOG.md, docs/_active/TODO.md, docs/_active/DECISIONS.md

- **What changed:** Created the full project plan for AIYO Wisper, a native macOS voice-to-text app built with Swift/SwiftUI and whisper.cpp. Generated MASTERPLAN.md with 3 phases (Core Dictation, Smart Formatting, Command Mode & Voice Shortcuts) and TODO.md with ~55 actionable tasks.
- **Decisions made:** Swift + SwiftUI + whisper.cpp stack, local-only processing, Apple Silicon first, DMG distribution, press-and-hold hotkey UX (Wispr Flow style), user-selectable Whisper model size, auto-language detection
- **Issues resolved:** None (first session)
- **New issues found:** None
- **Next up:** Start Phase 1 — create Xcode project, set up whisper.cpp dependency, implement audio recording
