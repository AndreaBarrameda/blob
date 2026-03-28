# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# CLI tool (in PATH)
blob start          # Build (if needed) + launch in background
blob stop           # Kill running instance
blob restart        # Stop + start
blob status         # Check if running
blob log            # Tail the log file
blob build          # Just build, don't run

# Manual build
swift build
swift build && swift run VirtualAssistant
```

### Requirements
- macOS 13+
- Swift 5.9+
- OpenAI API key in `.env` file (`OPENAI_API_KEY=sk-...`)
- `.env` search order: next to binary, project root, cwd, home dir

### macOS Permissions (prompted on first run)
- Screen Recording — for screenshot-based observation loop
- Accessibility — for reading typed text and focused UI elements
- Microphone — only if Listening Mode enabled

## Architecture

macOS floating window app — "Blob" is an AI desktop creature that watches the screen, reacts with personality, and remembers things about the user.

### AppDelegate (VirtualAssistantApp.swift)
Central orchestrator managing:
- **Window Management**: Blob window (300x300 borderless), dashboard panel, speech bubbles (child windows that follow blob)
- **Menu Bar Icon**: NSStatusItem — click to toggle dashboard panel
- **Observation Loop**: 15-second timer captures screen + system state → OpenAI GPT-4o vision → speech bubble
- **Ambient Awareness Loop**: 8-second timer for non-visual system context observations
- **Blob Clicks**: Cute/angry reactions on tap (dashboard moved to menu bar)
- **Mind State**: Tracks attachment, trust, fear, resentment, love levels that evolve with interactions

### OpenAIClient (OpenAIClient.swift)
- **Unified personality** (`OpenAIClient.personality`) — single static prompt shared by all 4 API code paths
- **Structured mood tags** — LLM prefixes responses with `[mood]` tag (e.g., `[playful] three tabs of stackoverflow`), parsed by `parseMoodTag()`. Falls back to keyword-based `inferMood()` if no tag present
- **4 API methods**: `chat`, `chatWithScreenAwareness`, `ambientObservation`, `observationRequest` — all use `makeChatRequest()` internally
- All methods return `(String, BlobMood)` — utterance + mood from the LLM

### BlobNativeView (BlobNativeView.swift)
NSView with custom `draw(_:)` rendering:
- **Organic body**: 64-vertex contour deformed by 3 overlapping sine waves (not a circle)
- **8-ring glow**: Smooth alpha falloff, organic shape, pulses with breathing
- **Eyes**: White sclera + black pupils, mouse-tracking with lerp inertia
- **Mouth**: Mood-specific shapes (smile, frown, O, flat line, pout)
- **Squash/stretch**: Bob velocity drives width/height deformation
- **Micro-movements**: Idle drift, breathing amplitude variation, double-blink (15% chance)
- **10 moods**: content, playful, curious, thoughtful, angry, annoyed, offended, afraid, alert, delighted

### BlobMemory (BlobMemory.swift)
- **MEMORY.md** — human-readable markdown file in project root, newest entries at top
- Created automatically on first launch if missing
- `extractMemories()` uses GPT to extract facts from conversations, deduplicates against existing knowledge
- `getMemorySummary()` feeds recent entries into every LLM prompt as context

### ConversationLog (ConversationLog.swift)
- **CONVERSATION.md** — full history of every exchange (chat, observation, ambient), newest at top
- Created automatically on first launch if missing
- `logChat()/logObservation()/logAmbient()` — append timestamped entries with type + mood
- `getRecentContext(limit:)` — returns last N exchanges formatted for LLM prompt, preventing repetition
- In-memory cache of last 20 entries for fast access; loads from file on startup

### Key Managers
- **SystemMonitor** — Battery level, running apps
- **SystemAwareness** — Real CPU/memory/disk usage (via `host_statistics64`, `vm_statistics64`, `FileManager`)
- **ScreenCapture** — Native `CGWindowListCreateImage` (primary) + `screencapture` CLI (fallback), JPEG at 40% quality
- **ContentCapture** — Clipboard + focused text field (Accessibility API) + InputAwarenessManager (key/mouse events)
- **InputAwarenessManager** — Global key/mouse event monitoring, 90-second retention window
- **AudioCaptureManager** — PCM audio capture + WAV conversion (Whisper pipeline incomplete — captures but doesn't transcribe)
- **SpotifyController** — AppleScript-based playback control + track info
- **SystemControl** — App launching, shell commands (with destructive command blocklist), file browsing

### UI
- **DashboardView** — SwiftUI panel: chat, toggles (listening/work/screen watch/ambient/speech), Spotify controls, mood legend, memory import/export, system control
- **SpeechBubbleWindow** — Child window of blob (follows when dragged), auto-hides after reading duration

## Data Flow

1. **Observation Cycle** (15s):
   Screen capture + system state + MEMORY.md + CONVERSATION.md (last 10) → GPT-4o vision → `[mood] utterance` → parse mood tag → set blob visual mood + show speech bubble → log to CONVERSATION.md

2. **Ambient Awareness** (8s):
   System signals only (no screenshot) + CONVERSATION.md (last 10) → GPT-4o → mood-tagged utterance → bubble → log to CONVERSATION.md

3. **Dashboard Chat**:
   User message + screen (if enabled) + context + CONVERSATION.md (last 10) → GPT-4o → response with mood → bubble → log to CONVERSATION.md + extract memories to MEMORY.md

4. **Memory Pipeline**:
   After each chat exchange → GPT extracts 1-2 facts → deduplicates → prepends to MEMORY.md → future prompts include recent memories

## Key Files

```
Sources/VirtualAssistant/
├── VirtualAssistantApp.swift     # AppDelegate — orchestrator, observation loops, mind state
├── OpenAIClient.swift            # Unified personality, mood tags, all API methods
├── BlobNativeView.swift          # Organic blob rendering + animations
├── BlobMemory.swift              # MEMORY.md read/write
├── ConversationLog.swift         # CONVERSATION.md — full exchange history + recent context for LLM
├── DashboardView.swift           # SwiftUI dashboard + ChatMessage/ChatBubble types
├── SpeechBubbleView.swift        # Speech bubble window
├── SystemAwareness.swift         # Real CPU/memory/disk via macOS APIs
├── SystemMonitor.swift           # Battery + running apps
├── SystemControl.swift           # App launch, shell exec, clipboard
├── SystemControlPanel.swift      # System control UI
├── ScreenCapture.swift           # Screenshot + base64
├── ContentCapture.swift          # Typed text extraction
├── InputAwarenessManager.swift   # Global key/mouse monitoring
├── AudioCaptureManager.swift     # Audio capture (transcription TODO)
├── TaskContextManager.swift      # Task tracking (work mode)
├── LocationWeatherManager.swift  # Location/weather context
├── SpotifyController.swift       # Playback control via AppleScript
├── SpotifyWebAPI.swift           # Spotify search URI opener
├── ImportMemoriesView.swift      # ChatGPT memory import
├── ExportMemoriesView.swift      # ChatGPT memory export
└── SystemInfoView.swift          # System info display
```

## Important Notes

- **Personality**: Defined once in `OpenAIClient.personality`. Blob is opinionated, teasing, tracks patterns — NOT a generic assistant
- **Mood System**: LLM returns `[mood]` tags parsed by `parseMoodTag()`. 10 moods drive visual state (body color, glow, eye shape, mouth)
- **Memory**: MEMORY.md in project root. Human-readable. Newest at top. Fed into every LLM call
- **No dock icon**: Runs as `.accessory` app. Menu bar icon toggles dashboard
- **Speech bubbles**: Child windows of blob — follow when dragged, auto-dismiss after word-count-scaled duration
- **`.env` not in repo**: API key loaded from `.env` file, searched in multiple locations
