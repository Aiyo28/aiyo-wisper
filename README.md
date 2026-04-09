# AIYO Wisper

Free, local voice-to-text for macOS. Hold a key, speak, text appears at your cursor. Everything runs on your device — no cloud, no subscription.

## Features

- **Hold-to-talk dictation** — Hold Control, speak, release. Text appears in any app.
- **AI text cleanup** — Built-in Qwen 3.5 4B removes filler words, fixes self-corrections, adds punctuation. All local.
- **Command mode** — Hold Option to transform selected text with voice commands ("make this formal", "translate to Spanish").
- **Voice shortcuts** — Custom trigger phrases that expand into longer text during dictation.
- **Multi-model** — Choose from 7 Whisper models (75 MB to 3 GB) for your speed/accuracy tradeoff.
- **Auto-update** — Sparkle-powered updates from GitHub Releases.

## Requirements

- macOS 15.0+
- Apple Silicon (M1 or later)
- ~75 MB minimum (tiny model) — up to ~5.5 GB with large Whisper + AI cleanup model

## Install

1. Download the latest DMG from [Releases](https://github.com/ayal/aiyo-wisper/releases)
2. Drag to Applications
3. Launch — grant Microphone and Accessibility permissions when prompted
4. Download a Whisper model in Settings → Transcription

## Usage

| Action | Hotkey | What happens |
|--------|--------|-------------|
| Dictate | Hold **Control** | Speak → text appears at cursor |
| Command mode | Hold **Option** | Speak a command → transforms selected text |

### AI Text Cleanup

Go to Settings → Formatting → AI Text Cleanup and download the model (~2.5 GB). Once downloaded, your dictation is automatically cleaned up by a local LLM — filler words removed, self-corrections fixed, punctuation added.

The same model powers command mode.

## Build from Source

```bash
# Prerequisites: Xcode 16+, XcodeGen
brew install xcodegen

# Clone and build
git clone https://github.com/ayal/aiyo-wisper.git
cd aiyo-wisper
xcodegen generate
open AiyoWisper.xcodeproj
# Build & Run (Cmd+R)
```

## Privacy

**All processing happens on your device.** No audio, text, or telemetry ever leaves your Mac. Whisper models and the LLM run entirely locally via CoreML and llama.cpp.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6 |
| UI | SwiftUI |
| Speech-to-text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML) |
| Text cleanup | [LLM.swift](https://github.com/eastriverlee/LLM.swift) + Qwen 3.5 4B |
| Text injection | CGEvent keyboard simulation |
| Auto-update | [Sparkle](https://sparkle-project.org/) |
| Build system | XcodeGen |

## License

MIT — see [LICENSE](LICENSE).
