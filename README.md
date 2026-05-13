# Oracle

A gorgeous, native macOS voice assistant — an open alternative to Siri. Speak naturally, and Oracle listens, thinks, speaks back, and can take action on your Mac using tools.

![macOS 15+](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Features

### Voice-First Interface
- **Siri-like floating orb UI** with gorgeous mesh-gradient animations
- **Global hotkey** activation (default: `Cmd+Shift+Space`, fully configurable)
- **Touch Bar button** on supported MacBooks for one-tap activation
- **Auto-listening** when the panel opens — just start talking
- **Auto-silence detection** stops listening after 2 seconds of quiet

### Multi-Turn Conversations
Oracle keeps conversation context for the entire session. Ask follow-up questions, refer to previous answers, and have natural back-and-forth dialog. The conversation resets when the panel is dismissed or after the inactivity timeout.

### On-Device Text-to-Speech (Supertonic)
- **Lightning-fast, on-device synthesis** via [Supertonic](https://github.com/supertone-inc/supertonic) ONNX Runtime
- **Default voice: M2** (deep, robust male)
- **10 voices available**: M1–M5 (male), F1–F5 (female)
- Configurable quality steps (4–15) and speech speed
- No cloud dependency, fully private

### API-Based Speech-to-Text
- Uses configurable API providers (OpenAI Whisper, GPT-4o-transcribe, or any compatible endpoint)
- Recorded audio is sent securely to your chosen STT endpoint
- Planned upgrade path to on-device Voxtral Small in the future

### Configurable LLM Providers
- Add any **OpenAI-compatible API** provider with custom base URL
- Support for **multiple models per provider**
- API keys stored securely in the macOS Keychain
- Full streaming responses with real-time transcription display

### Tool Use — Oracle Can Do Things
Oracle can invoke tools to help you. Before any destructive action, Oracle asks for your confirmation.

Available tools:
- **`web_search`** — Search the web via DuckDuckGo
- **`fetch_url`** — Fetch and read web page content
- **`execute_shell`** — Execute shell commands (destructive commands require confirmation)
- **`run_applescript`** — Control macOS apps and system features
- **`list_directory`** — Browse files and folders
- **`read_file`** — Read text file contents

### No Fallbacks — Clear Errors Everywhere
If anything goes wrong, Oracle **shows the error** instead of silently failing:
- TTS executable missing? Clear error banner with fix instructions.
- LLM API returned 401? Error shown with the HTTP response.
- Microphone permission denied? Guided message to System Settings.
- Tool execution failed? Error details returned to the conversation.

### Smart Session Management
- Panel **stays open** after responding so you can continue the conversation
- **Auto-dismiss** after configurable inactivity timeout (default: 30s)
- Press `Escape` or click outside to dismiss manually

## Architecture

```
Oracle/
├── Sources/Oracle/
│   ├── Models/              # Data models (Provider, AIModel, Conversation, Tools)
│   ├── Services/            # Core services (TTS, STT, LLM, Audio, Tools)
│   ├── UI/                  # SwiftUI views (Orb, Panel, Settings, Touch Bar)
│   ├── Utils/               # Keychain, networking, multipart form builder
│   ├── AppState.swift       # Central @Observable state coordinator
│   └── OracleApp.swift      # App entry, MenuBarExtra, window management
├── Resources/
│   ├── Info.plist           # LSUIElement app configuration
│   └── Oracle.entitlements  # Sandboxing + permissions
├── setup.sh                 # One-command setup script
└── project.yml              # XcodeGen project specification
```

## Requirements

- **macOS 15.0+** (for MeshGradient and modern SwiftUI)
- **Xcode 16+** with Swift 6
- **Homebrew** (for git-lfs, xcodegen)
- **Git with LFS** (for downloading Supertonic models)

## Setup

### 1. Clone this repository

```bash
git clone <your-repo-url> oracle
cd oracle
```

### 2. Run the setup script

```bash
./setup.sh
```

This will:
- Install `xcodegen` and `git-lfs` (via Homebrew)
- Clone the [Supertonic](https://github.com/supertone-inc/supertonic) repository
- Download ONNX models and voice styles from HuggingFace (~100MB)
- Build the Supertonic Swift executable
- Generate `Oracle.xcodeproj`

### 3. Open in Xcode and configure

```bash
open Oracle.xcodeproj
```

- Select your **Development Team** for code signing
- Build and run (`Cmd+R`)

### 4. Configure providers

On first launch:
1. Click the **Oracle icon** in your menu bar
2. Select **Settings...**
3. Add your LLM provider (e.g., OpenAI, OpenRouter, local Ollama)
4. Add models for that provider
5. Set your **STT provider** and model ID (e.g., `whisper-1` or `gpt-4o-transcribe`)
6. Customize your **voice**, **hotkey**, and **behavior**

## Usage

| Action | How |
|--------|-----|
| Activate Oracle | `Cmd+Shift+Space` (default) or click menu bar icon |
| Start talking | Oracle auto-listens when the panel appears |
| Stop talking | Silence for 2 seconds auto-submits, or tap the orb |
| Dismiss | `Escape`, click outside, or wait for inactivity timeout |
| Open Settings | Menu bar → Settings... (`Cmd+,`) |
| Touch Bar | Tap the waveform orb button |

## Customization

### Changing the Global Hotkey
Go to **Settings → Shortcuts** and record a new global shortcut. The default is `Cmd+Shift+Space`.

### Adding LLM Providers
Go to **Settings → LLM Providers → Add Provider**. Enter:
- **Name**: Display name (e.g., "OpenRouter")
- **Base URL**: API base URL (e.g., `https://openrouter.ai/api/v1`)
- **API Key**: Your API key (stored in Keychain)

Then add models under **Settings → Models**.

### Changing Voice
Go to **Settings → Voice & Behavior** and select from M1–M5 / F1–F5.

### Adjusting Quality vs Speed
- **Fast (4 steps)**: Quickest response, slightly lower fidelity
- **Balanced (8 steps)**: Default, good trade-off
- **High (10 steps)**: Better quality
- **Ultra (15 steps)**: Best quality, slower

## Security

- **API keys** are stored in the macOS Keychain, never in UserDefaults or plain text
- **Destructive shell commands** (rm, mv, dd, etc.) require explicit user confirmation
- The app runs in the **App Sandbox** with hardened runtime
- All TTS inference happens **on-device** — your text never leaves your Mac for speech synthesis

## Roadmap

- [ ] On-device STT (Voxtral Small or Whisper.cpp)
- [ ] Custom wake word / always-listening mode
- [ ] Conversation persistence (optional)
- [ ] More tool integrations (Calendar, Reminders, Spotify, etc.)
- [ ] Vision capabilities (screen understanding)
- [ ] Plugin system for custom tools

## Acknowledgments

- **TTS**: [Supertonic](https://github.com/supertone-inc/supertonic) by Supertone Inc. — lightning-fast on-device TTS
- **Hotkeys**: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- **ONNX Runtime**: Microsoft

## License

MIT License — see LICENSE for details.
Supertonic models are released under the OpenRAIL-M License.
