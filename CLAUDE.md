# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build and Run
```bash
# Build from command line
swift build

# Run the app
swift run VirtualAssistant

# Build and run in one command
swift build && swift run VirtualAssistant

# Open in Xcode
open -a Xcode .
```

### Requirements
- macOS 13+
- Swift 5.9+
- Xcode 14+ (for development)
- OpenAI API key in `.env` file

## Architecture

This is a macOS floating window app featuring "Blob" — an AI assistant character that monitors the system and provides witty commentary.

### Core Module: AppDelegate (VirtualAssistantApp.swift)
The `AppDelegate` is the central orchestrator that manages:
- **Window Management**: Controls the floating blob window, dashboard panel, and speech bubbles
- **Timed Observation Loop**: Every 15 seconds, captures screen and system state, sends to OpenAI, and displays responses
- **User Interaction**: Handles blob clicks to toggle dashboard; 5+ rapid clicks triggers "angry" mood
- **State Persistence**: Stores user preferences (work mode, listening mode) in `UserDefaults`

### Key Managers
Each manager encapsulates a specific system capability:

- **SystemMonitor** — Tracks battery level, running apps, system status
- **OpenAIClient** — API wrapper for GPT-4o chat/vision and audio transcription
- **AudioCaptureManager** — Records system audio (for listening mode)
- **ScreenCapture** — Screenshots and encodes as base64 for vision API
- **ContentCapture** — Extracts recently typed text from frontmost app
- **SystemAwareness** — Gathers detailed system info (CPU, memory, disk, network)
- **TaskContextManager** — Tracks user's current tasks (work mode only)
- **LocationWeatherManager** — Provides location/weather context
- **SpotifyController** — Reads currently playing track

### UI Architecture

- **BlobNativeView** — Animated blob rendering (mood states: content, playful, thoughtful, curious, alert, angry)
- **SpeechBubbleView/SpeechBubbleWindow** — Displays Blob's utterances above the blob for 4 seconds
- **DashboardView** — Main panel showing chat, system info, controls (appears on blob click)
- **BlobMemory** — Persistent memory system stored in `.blob_memory.json`

### Data Flow

1. **Observation Cycle** (15-second timer):
   - Capture screen, typed content, system state, task context
   - Build comprehensive context string
   - Send to OpenAI with system prompt defining Blob's personality (witty, sarcastic, system-aware)
   - Parse mood from response (angry, playful, thoughtful, curious)
   - Update blob mood animation and display speech bubble

2. **User Interaction**:
   - Blob tap → toggle dashboard
   - 5+ rapid taps → trigger "angry" mood with sarcastic response
   - Dashboard interactions → modify modes, preferences

3. **State Persistence**:
   - Work mode / Listening mode → `UserDefaults`
   - Blob memories → `.blob_memory.json`
   - Blob consciousness state → system files

## Key Design Patterns

### Delegation
- `BlobConsciousnessDelegate` protocol allows mood/speech responses to propagate back to AppDelegate UI updates

### Timers
- 15-second observation loop (main character loop)
- 2-second click reset (for multi-click detection)
- 0.5-second window ordering (keeps blob on top)
- 4-second speech bubble auto-hide

### Environment & Secrets
- API keys stored in `.env` file (NOT version controlled, see `.gitignore`)
- OpenAI API key required: `OPENAI_API_KEY`
- Optional: Spotify device ID for music control

## Important Notes

- **Mood System**: BlobMood enum (content, playful, thoughtful, curious, alert, angry) drives visual state
- **System Awareness**: Blob references specific apps, files, battery %, CPU usage in responses — this requires real data capture
- **Performance**: Screen capture + base64 encoding happens every 15 seconds; consider memory/CPU impact if reducing interval
- **Window Behavior**: Blob runs as accessory app (no dock icon); windows have `.canJoinAllSpaces` behavior
- **Animations**: Blob mood changes are animated; speech bubbles fade with auto-dismiss
- **Error Handling**: Missing API key will cause API calls to fail silently; check `.env` file first

## Directory Structure

```
Sources/VirtualAssistant/
├── VirtualAssistantApp.swift          # App entry point & AppDelegate
├── BlobNativeView.swift               # Blob animation rendering
├── BlobMemory.swift                   # Persistent memory management
├── BlobConsciousness.swift            # AI decision/mood logic
├── SpeechBubbleView.swift             # Utterance display
├── DashboardView.swift                # Main UI panel
├── SystemMonitor.swift                # System info tracking
├── SystemAwareness.swift              # Detailed system data
├── SystemControl.swift                # System interaction
├── SystemControlPanel.swift           # System control UI
├── OpenAIClient.swift                 # API wrapper
├── AudioCaptureManager.swift          # Audio recording
├── ScreenCapture.swift                # Screen capture/encode
├── ContentCapture.swift               # Typed text extraction
├── TaskContextManager.swift           # Task tracking
├── LocationWeatherManager.swift       # Location/weather
└── SpotifyController.swift            # Music integration
```
