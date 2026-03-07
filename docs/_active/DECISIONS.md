# Decisions

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
