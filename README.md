<p align="center">
  <img src="assets/banner.svg" alt="AIYO Wisper — Local voice-to-text for macOS" width="100%">
</p>

Hold a key, speak, text appears at your cursor. No cloud. No subscription. Everything runs on your Mac.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[**Download DMG**](https://github.com/Aiyo28/aiyo-wisper/releases/latest) · [Build from Source](#build-from-source)

---

## What it does

**Dictation** — Hold Control, speak, release. Text appears wherever your cursor is. In any app.

**Smart Formatting** — Automatic punctuation and capitalization on your dictated text, with light cleanup of false starts. Rule-based and instant — no AI model required.

**Voice Shortcuts** — Create trigger phrases that expand during dictation. Say "my email" and it types your full email address.

## How it compares

| | AIYO Wisper | SuperWhisper | Wispr Flow |
|---|:---:|:---:|:---:|
| Price | **Free** | $10/mo | $15/mo |
| Local processing | Yes | Cloud | Cloud |
| Voice shortcuts | Yes | — | — |
| Open source | MIT | No | No |
| Privacy | No data leaves Mac | Audio sent to cloud | Audio sent to cloud |

## Requirements

- macOS 15.0+
- Apple Silicon (M1 or later)

## Install

1. Download the latest DMG from [Releases](https://github.com/Aiyo28/aiyo-wisper/releases/latest)
2. Drag to Applications
3. Launch — grant Microphone and Accessibility permissions
4. Pick a speech model in Settings → Transcription

## Models

| Model | Size | Best for |
|-------|------|----------|
| **Turbo** (recommended) | 632 MB | Highest accuracy. All languages. |
| Small | 216 MB | Balanced multilingual option. Use Turbo for higher accuracy. |
| English Turbo | 600 MB | Fastest for English. **Will not transcribe other languages.** |
| Lightweight | 77 MB | Smallest download. Quick notes. All languages. |

## Privacy

**No audio or text ever leaves your device.** All speech recognition (WhisperKit) runs entirely on your Mac using the Neural Engine and GPU. No cloud APIs, no telemetry, no accounts.

## Build from Source

```bash
brew install xcodegen
git clone https://github.com/Aiyo28/aiyo-wisper.git
cd aiyo-wisper
xcodegen generate
open AiyoWisper.xcodeproj
# Cmd+R to build and run
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6 |
| UI | SwiftUI |
| Speech-to-text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML) |
| Text injection | CGEvent keyboard simulation |
| Auto-update | [Sparkle](https://sparkle-project.org/) |

## License

MIT — see [LICENSE](LICENSE).
