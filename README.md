<p align="center">
  <img src="Resources/banner.png" alt="Oracle Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15.0+-0A84FF?style=flat-square&logo=apple&logoColor=white">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square">
</p>

---

I built Oracle because Siri failed me one too many times, and she never explained why. Voice is the most intimate interface we have — it deserves honesty, not a polite shrug. 🤍

Oracle is a native macOS voice assistant that lives in your menu bar. Press a hotkey, speak, and it listens. It transcribes via the STT provider you choose, reasons through the LLM you trust, speaks back in a voice synthesized entirely on your Mac, and can take action through tools — but only when you say so, and never without showing its work. When something breaks, it tells you. No fallbacks, no fake confidence. 🛡️

## What It Does

| Feature | Description |
|---------|-------------|
| **Voice-first UI** | Global hotkey (`Cmd+Shift+Space`), Touch Bar support, auto-listen, auto-silence detect |
| **Multi-turn chat** | Conversations persist across the session — follow-ups, references, context |
| **On-device TTS** | [Supertonic](https://github.com/supertone-inc/supertonic) ONNX Runtime, 10 voices, zero cloud |
| **Any LLM** | OpenAI-compatible providers (OpenAI, OpenRouter, Ollama, etc.), streaming responses |
| **Any STT** | Whisper, GPT-4o-transcribe, or any compatible `/audio/transcriptions` endpoint |
| **Tools** | Web search, fetch URL, shell commands, AppleScript, file browse/read |
| **No fallbacks** | Every error surfaces in the UI — missing binaries, API failures, permission denials |

## Architecture

```
Sources/Oracle/
├── Models/              # Providers, models, conversations, tools
├── Services/            # TTS, STT, LLM, audio, hotkeys
├── UI/                  # Orb, panel, settings, touch bar
├── Utils/               # Keychain, networking
├── AppState.swift       # @Observable @MainActor coordinator
└── OracleApp.swift      # LSUIElement entry
```

`AppState` orchestrates the full pipeline — listen → transcribe → stream LLM → execute tools → speak → listen again — without blocking the main thread. Pure SwiftUI: `MeshGradient`, glassmorphism, `VisualEffectBlur`. No UIKit compromises.

## Setup

macOS 15.0+, Xcode 16, Homebrew.

```bash
git clone https://github.com/CodeDreamer06/Oracle.git oracle
cd oracle
./setup.sh      # installs deps, downloads TTS models (~100MB), generates Xcode project
open Oracle.xcodeproj
```

Select your team, build (`Cmd+R`). On first launch, open **Settings** from the menu bar, add your providers, pick a voice. Then press `Cmd+Shift+Space` and talk.

## Usage

| Action | How |
|--------|-----|
| Activate | `Cmd+Shift+Space` or click menu bar icon |
| Talk | Auto-starts when panel opens |
| Stop | 2s silence auto-submits, or tap the orb |
| Dismiss | `Escape`, click outside, or inactivity timeout |
| Settings | Menu bar → Settings (`Cmd+,`) |
| Touch Bar | Tap the waveform orb |

## Security

- API keys in macOS Keychain, never plaintext
- Destructive shell commands require confirmation
- TTS is fully on-device
- Sandboxed + hardened runtime

## Roadmap

- [ ] On-device STT (Voxtral Small / Whisper.cpp)
- [ ] Custom wake word / always-listening
- [ ] Conversation persistence
- [ ] More tools (Calendar, Reminders, Spotify)
- [ ] Vision / screen understanding
- [ ] Plugin system for custom tools

## Acknowledgments

- [Supertonic](https://github.com/supertone-inc/supertonic) by Supertone Inc.
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus

## License

MIT. Supertonic models: OpenRAIL-M.
