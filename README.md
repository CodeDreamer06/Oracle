<p align="center">
  <img src="Resources/banner.png" alt="Oracle Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15.0+-0A84FF?style=flat-square&logo=apple&logoColor=white">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square">
</p>

---

I built Oracle because I was tired of asking Siri to do something simple and watching her fail silently. She would misunderstand, or give up, or offer me a web search with the confidence of a concierge who has never heard of Google. The worst part wasn't the failure — it was the *opacity*. I never knew what she heard, what she thought, or why she gave up. Voice is the most intimate interface we have. It deserves honesty. 🤍

Oracle is a native macOS voice assistant that sits in your menu bar and listens when you call. It is not a product. It is a piece of software I wrote because I believe the computer on my desk should understand me when I speak, should tell me when it is confused, and should never pretend everything is fine while doing nothing at all.

## Why Not Just Use Siri?

Siri is a black box wrapped in a pleasant voice. She lives inside Apple's ecosystem, answers to Apple's priorities, and when she cannot help, she apologizes in ways that teach us to lower our expectations. I wanted something different. I wanted an assistant that uses the LLM I choose, the voice I prefer, and the tools I have already built on my machine. I wanted an assistant that errs loudly rather than failing quietly — because a tool that lies about its competence is worse than no tool at all.

Oracle is open. Its brain is whichever OpenAI-compatible API you point it at. Its ears are Whisper or whatever STT provider you trust. Its voice is synthesized on your Mac via [Supertonic](https://github.com/supertone-inc/supertonic), so your words never leave the machine to become speech. It can search the web, read your files, run shell commands, and control your Mac with AppleScript — but only when you say so, and never without showing its work. 🛡️

## What It Feels Like

Press `Cmd+Shift+Space`. A floating orb appears in the top-right corner of your screen, pulsing with a mesh gradient that shifts between purple and blue like something alive. Start talking. The orb turns green and breathes with your voice. Stop talking, and after two seconds of silence it thinks — the orb turns orange, spins — then speaks back in a deep, synthetic voice that lives entirely on your hardware.

The conversation stays open. Ask a follow-up. Refer to what it just said. The orb remembers, because the conversation is yours, not a transaction to be discarded. When you are done, press Escape, click away, or simply wait. It fades.

## Features

**Voice-First Interface**
- Global hotkey activation (default `Cmd+Shift+Space`, fully configurable)
- Touch Bar button on supported MacBooks
- Auto-listens when the panel opens — no clicking, no awkward pauses
- Auto-silence detection stops recording after 2 seconds of quiet
- Multi-turn conversations that persist for the entire session

**On-Device Speech Synthesis**
- Lightning-fast TTS via Supertonic ONNX Runtime, fully private
- 10 voices: M1–M5, F1–F5 (default: M2, a deep male voice)
- Configurable quality steps and speech speed
- Zero network calls for speech generation

**Configurable Intelligence**
- Any OpenAI-compatible LLM provider (OpenAI, OpenRouter, local Ollama)
- Multiple models per provider
- Streaming responses with real-time display
- API keys stored in the macOS Keychain, never in plain text

**It Can Act**
- `web_search` — Search via DuckDuckGo
- `fetch_url` — Read web pages
- `execute_shell` — Run shell commands (destructive ones require your confirmation)
- `run_applescript` — Automate macOS apps
- `list_directory` & `read_file` — Browse and read your files

**No Fallbacks**
Every failure surfaces as a clear error banner. Missing binary, API error, permission denied — you see exactly what went wrong. Oracle does not pretend to understand when it does not. That is the whole point.

## Architecture

```
Oracle/
├── Sources/Oracle/
│   ├── Models/              # Providers, models, conversations, tools
│   ├── Services/            # TTS, STT, LLM, audio, hotkeys
│   ├── UI/                  # Orb, panel, settings, touch bar
│   ├── Utils/               # Keychain, networking, multipart builder
│   ├── AppState.swift       # @Observable @MainActor coordinator
│   └── OracleApp.swift      # LSUIElement entry point
├── Resources/
│   ├── Info.plist           # Menu bar app configuration
│   ├── Oracle.entitlements  # Sandboxing + permissions
│   └── supertonic/          # Bundled ONNX TTS models
├── setup.sh                 # One-command setup
└── project.yml              # XcodeGen specification
```

`AppState` is the single source of truth. It orchestrates the entire pipeline — listening, transcribing, streaming LLM responses, executing tools, speaking, and listening again — all without blocking the main thread. The UI is pure SwiftUI with `MeshGradient`, glassmorphism, and `VisualEffectBlur`. No UIKit bridges, no compromises.

## Setup

You need macOS 15.0+, Xcode 16, and Homebrew.

```bash
git clone <your-repo-url> oracle
cd oracle
./setup.sh
```

This installs dependencies, clones Supertonic, downloads ONNX models (~100MB), builds the TTS executable, and generates `Oracle.xcodeproj`.

```bash
open Oracle.xcodeproj
```

Select your development team, build, and run.

On first launch, open **Settings** from the menu bar, add your LLM and STT providers, and choose a voice. Then press `Cmd+Shift+Space` and talk.

## Usage

| Action | How |
|--------|-----|
| Activate | `Cmd+Shift+Space` or click the menu bar icon |
| Talk | Starts automatically when the panel opens |
| Stop | Silence for 2s auto-submits, or tap the orb |
| Dismiss | `Escape`, click outside, or wait for timeout |
| Settings | Menu bar → Settings (`Cmd+,`) |
| Touch Bar | Tap the waveform orb |

## Security

- API keys live in the macOS Keychain
- Destructive commands require explicit confirmation
- TTS runs entirely on-device
- Sandboxed with hardened runtime

## Roadmap

- [ ] On-device STT (Voxtral Small or Whisper.cpp)
- [ ] Custom wake word / always-listening mode
- [ ] Conversation persistence
- [ ] More tools: Calendar, Reminders, Spotify
- [ ] Vision capabilities (screen understanding)
- [ ] Plugin system for custom tools

## Acknowledgments

- [Supertonic](https://github.com/supertone-inc/supertonic) by Supertone Inc. — for proving on-device TTS can be beautiful
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus — for effortless global hotkeys

## License

MIT License. Supertonic models are released under the OpenRAIL-M License.
