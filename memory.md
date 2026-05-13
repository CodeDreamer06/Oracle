# Oracle Project — Session Memory

## Project Overview
Building **Oracle** — a native macOS voice assistant (Siri alternative) at `/Users/abhinav/Projects/oracle`.

## What's Been Built

### Core Architecture
- **Framework**: Swift 6 + SwiftUI, macOS 15.0+ minimum
- **App Type**: LSUIElement (no dock icon), MenuBarExtra status bar app
- **State**: `@Observable @MainActor AppState` coordinates everything
- **Build Status**: ✅ Compiles successfully (`xcodebuild` passes)

### Services Implemented
1. **SupertonicTTS** — Subprocess-based TTS using Supertonic's `example_onnx` executable
   - Default voice: M2 (deep male)
   - 10 voices available: M1-M5, F1-F5
   - Configurable quality steps (4/8/10/15) and speech speed
   - Expects executable at `../supertonic/swift/.build/release/example_onnx`
   - Expects assets at `../supertonic/assets/`

2. **SpeechRecognitionService** — API-based STT using OpenAI-compatible `/audio/transcriptions`
   - Configurable provider and model (default: whisper-1)
   - Records to m4a, uploads via multipart form data

3. **LLMService** — Streaming chat completions with tool use
   - Uses `AsyncThrowingStream.makeStream()` for SSE parsing
   - Supports OpenAI-compatible endpoints
   - Handles both text deltas and tool call accumulation
   - Multi-turn: full conversation history sent with each request

4. **ToolExecutor** — 6 tools available:
   - `web_search` — DuckDuckGo HTML scraping
   - `fetch_url` — URL content fetching
   - `execute_shell` — Shell commands (destructive ones require confirmation)
   - `run_applescript` — macOS automation
   - `list_directory` — File browsing
   - `read_file` — Text file reading

5. **AudioRecorder** — AVAudioEngine-based recording to m4a
6. **AudioPlayerService** — AVAudioPlayer with delegate-based completion
7. **HotkeyManager** — KeyboardShortcuts package, default Cmd+Shift+Space

### UI Components
- **OrbView** — MeshGradient-based animated orb with 5 states (idle/listening/thinking/speaking/toolExecuting)
- **AssistantPanel** — 520x520 floating NSPanel with VisualEffectBlur background
- **ConversationView** — Scrollable message bubbles with streaming indicators
- **ToolConfirmationView** — Inline confirmation for destructive tool operations
- **SettingsView** — Provider/model/voice/hotkey configuration with Keychain-backed API keys
- **ErrorBanner** — Inline error display (no fallbacks policy)

### Key Behaviors
- **Activation**: Global hotkey or menu bar click opens panel + auto-starts listening
- **Auto-silence**: Stops listening after 2 seconds of silence
- **Session**: Panel stays open for multi-turn conversation; dismisses after inactivity timeout (default 30s)
- **Errors**: Every service surfaces errors via `OracleError` banner in UI
- **Touch Bar**: Orb button on supported MacBooks

## Current Status

### ✅ Recently Fixed / Completed
1. **OracleApp.swift warnings** — Fixed MainActor isolation warning in `hidePanel()` completion handler using `MainActor.assumeIsolated`. Also fixed `LSMinimumSystemVersion` in Info.plist (14.0 → 15.0).
2. **setup.sh** — Successfully ran. Supertonic repo cloned, ONNX models downloaded (~382MB), executable built, and Xcode project regenerated.
3. **AudioRecorder format mismatch** — File settings now use the input node's actual sample rate and channel count instead of hardcoded 44.1kHz/mono, preventing AVAudioFile write failures.
4. **ToolExecutor main actor blocking** — Replaced synchronous `process.waitUntilExit()` with async `terminationHandler` + `withCheckedThrowingContinuation`, preventing UI freezes during shell command execution.
5. **AudioPlayerService race condition** — Replaced singleton `PlayerDelegate` with per-playback delegate instances, preventing continuation leaks and wrong-task-resumption when playback is interrupted.

### ⚠️ Known Issues / Remaining Work
1. **Testing**: Full pipeline (hotkey → record → STT → LLM → TTS → speak) has not been tested yet.
2. **Provider API keys**: Currently stored via KeychainHelper but the UI flow needs validation.

### Project Files Location
All source code is in `/Users/abhinav/Projects/oracle/`.

### Next Steps After Restart
1. ✅ Fix the 2 warnings in OracleApp.swift
2. ✅ Run `./setup.sh` to download Supertonic models
3. Build and verify the project compiles cleanly
4. Open project in Xcode, configure signing, build & run
5. Test the full voice pipeline end-to-end
6. Address any runtime issues

## User Requirements (Committed)
- ✅ Supertonic TTS with M2 default
- ✅ Configurable voice selection (M1-M5, F1-F5)
- ✅ API-based STT (Whisper/GPT-4o-transcribe)
- ✅ Configurable LLM providers (OpenAI-compatible, multiple models per provider)
- ✅ Multi-turn conversations within a session
- ✅ Tool use (web, shell, AppleScript, filesystem)
- ✅ Destructive command confirmation UI
- ✅ No fallbacks — show errors everywhere
- ✅ Gorgeous macOS UI with Siri-like orb
- ✅ Global hotkey (Cmd+Shift+Space default, configurable)
- ✅ Touch Bar support
- ✅ Auto-dismiss after inactivity
- ✅ macOS 26 (Tahoe) compatible

## Skill Installation Pending
User is installing `https://github.com/hmohamed01/swift-development` skill and will restart the agent. After restart, load the skill and apply any relevant Swift/macOS development guidelines to improve the codebase.
