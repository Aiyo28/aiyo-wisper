# Decisions

### 2026-03-07 — WhisperKit over whisper.cpp, XcodeGen project setup

- **WhisperKit** chosen over whisper.cpp — pure Swift/CoreML, Neural Engine acceleration, no C++ bridging needed
- **XcodeGen** for project generation — `project.yml` -> `.xcodeproj`, avoids merge conflicts on project files
- **Control key** as hold-to-record hotkey (changed from fn) — standard modifier, detected via `NSEvent.addGlobalMonitorForEvents(.flagsChanged)`
- **SMAppService** for launch-at-login — native macOS API, no third-party dependency
- **No App Sandbox** — required for CGEvent text injection and global hotkey monitoring
- **Entitlements excluded from sources** in project.yml to avoid "modified during build" Xcode error

### 2026-03-07 — Core architecture and stack decisions

- **Stack:** Swift + SwiftUI + whisper.cpp — native macOS for best OS integration and performance
- **Processing:** Local-only, no cloud APIs — privacy is a core product principle
- **Target hardware:** Apple Silicon first, Intel is nice-to-have
- **Distribution:** DMG / GitHub releases (no App Store due to Accessibility API usage)
- **UX model:** Press-and-hold global hotkey (default: fn) to record, release to transcribe and inject text — modeled after Wispr Flow
- **Whisper model:** User-selectable (tiny/base/small/medium/large), stored in Application Support
- **Language:** Auto-detect via Whisper's built-in language ID (Phase 2)
- **Text injection:** CGEvent keyboard simulation with clipboard-paste fallback
- **Pricing:** Free and open-source, no subscription
- **Smart formatting approach:** TBD — rule-based vs. local LLM (open decision for Phase 2)
