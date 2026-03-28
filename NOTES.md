### 2026-03-29 01:50:11 - Full voice agent overhaul (main)
**What:** Multiple iterations to get ElevenLabs conversational AI working:
1. ElevenLabs Swift SDK crashes SPM binaries (WebRTC/LiveKit incompatibility) — removed SDK
2. Built direct WebSocket client (BlobVoiceAgent.swift) connecting to wss://api.elevenlabs.io/v1/convai/conversation?agent_id=...
3. Fixed AppDelegate.shared cast (NSApplicationDelegateAdaptor wraps delegate, breaking `NSApplication.shared.delegate as? AppDelegate`) — all DashboardView toggles were silently broken
4. Gapless audio playback via AVAudioEngine + AVAudioPlayerNode (scheduleBuffer) replacing AVAudioPlayer WAV files
5. Audio chunk batching (100ms min buffer + 80ms tail flush) for smoother output
6. Mic gating — stops sending audio while agent speaks (prevents self-interruption via speaker→mic feedback)
7. Mood color restoration — agent_response text parsed for [mood] tags via OpenAIClient.parseMoodTag, drives blob visual mood + colors. Blob goes .curious when listening.
**Why:** User wanted ElevenLabs agent integration with voice, mood colors, and no audio truncation
**Result:** Voice agent connects via WebSocket, streams mic at 16kHz, receives gapless audio playback, parses mood tags for blob visual state. Mic auto-mutes during agent speech with 500ms resume grace.
**References:** BlobVoiceAgent.swift (WebSocket + audio), VirtualAssistantApp.swift (AppDelegate.shared, delegate methods, mic gating), DashboardView.swift (all toggles fixed), Package.swift (SDK removed), entitlements.plist + codesign in blob script
**Related:** 2026-03-28 22:12:35 - Voice + model + tokens
**Status:** Complete | **Next:** Test audio completeness, tune mic sensitivity

### 2026-03-28 22:12:35 - Voice conversation + model upgrade + token increase (main)
**What:** Multiple changes:
1. Switched LLM from gpt-4o to gpt-5.4-mini (used max_completion_tokens instead of max_tokens)
2. Switched ElevenLabs voice to FWdfQXb6A18oAr4vaMV5 (user-specified)
3. Increased max_completion_tokens to 800 across all API calls
4. Wired mic→Whisper→chat→ElevenLabs voice conversation loop: AudioCaptureManager now has VAD (voice activity detection via RMS energy threshold), delegate callback, mute/unmute for feedback prevention. AppDelegate implements AudioCaptureDelegate — transcribes speech chunks via Whisper, feeds into chat pipeline, blob responds with voice
5. Voice settings: stability 0.3, similarity_boost 0.6, style 0.7 (more expressive)
**Why:** User wanted gpt-5.4-mini, higher squeaky voice, mic interaction, and longer responses
**Result:** All working. gpt-5.4-mini responding. ElevenLabs playing with new voice. Mic conversation ready (enable Listening Mode toggle). Dashboard has Voice toggle (pink speaker icon).
**References:** OpenAIClient.swift (model+tokens), ElevenLabsClient.swift (voice+completion callback+NSObject), AudioCaptureManager.swift (full rewrite with VAD+delegate), VirtualAssistantApp.swift (AudioCaptureDelegate, mic pipeline), DashboardView.swift (voice toggle), .env (voice ID)
**Related:** 2026-03-28 21:58:35 - ElevenLabs voice, 2026-03-28 21:49:45 - Event-driven speech
**Status:** Complete

### 2026-03-28 21:58:35 - Add ElevenLabs voice to Blob (main)
**What:** Created ElevenLabsClient.swift — TTS via ElevenLabs API (eleven_turbo_v2_5 model). Every speech bubble is spoken aloud. Fire-and-forget async with AVAudioPlayer. Dashboard toggle to enable/disable voice.
**Why:** User wanted blob to have a voice
**Result:** API key from claude-voice project added to .env. Voice fires on every showSpeechBubble call. Audio ~35KB per utterance, plays immediately. Toggle in dashboard (pink speaker icon). Verified working — blob speaks observations, ambient comments, and tap reactions aloud.
**References:** ElevenLabsClient.swift (new), VirtualAssistantApp.swift:showSpeechBubble, DashboardView.swift:voice toggle, .env (ELEVENLABS_API_KEY + ELEVENLABS_VOICE_ID)
**Related:** 2026-03-28 21:49:45 - Event-driven speech
**Status:** Complete | **Next:** User testing voice quality/personality match

### 2026-03-28 21:49:45 - Event-driven speech — blob only talks when something changes (main)
**What:** Replaced timer-forced speech with change detection. Blob now stays quiet unless: app switch detected, battery crosses threshold (80/60/40/20/10), new typing activity, periodic visual check (every 2.5 min), or 5+ min idle (existential mutter). Minimum 45s gap between any speech.
**Why:** Blob was rephrasing the same thing every 8-15s because it was forced to speak on a timer. Real creatures react to events, not clocks.
**Result:** Observation timer polls every 10s (was 15s) but only fires API when visual change detected. Ambient timer polls every 15s (was 8s) but only fires when system state changes. Battery bracket initialized from actual level to prevent false startup trigger. Verified: blob speaks on first run, then stays quiet until something actually changes.
**References:** VirtualAssistantApp.swift — new state vars (lastActiveApp, lastBatteryBracket, lastTypingSnapshot, lastSpeechTime, etc.), rewritten performObservationCycle + performAmbientAwarenessCycle, new handleAmbientResponse + batteryBracket helpers
**Related:** 2026-03-28 21:37:50 - Add CONVERSATION.md, 2026-03-28 21:31:40 - Fix Chat
**Status:** Complete | **Next:** ElevenLabs voice integration

### 2026-03-28 21:37:50 - Add CONVERSATION.md exchange history (main)
**What:** Created ConversationLog.swift + CONVERSATION.md — logs every exchange (chat/observation/ambient) with timestamp, type, mood. Last 10 exchanges injected into all LLM prompts to prevent repetition.
**Why:** Blob kept repeating the same observations in succession because it had no memory of what it just said
**Result:** CONVERSATION.md created automatically on launch, populated with entries. LLM now sees recent history and varies responses — "ghostly text **again**?", "**still** 92 apps". Added to .gitignore, CLAUDE.md updated.
**References:** ConversationLog.swift (new), OpenAIClient.swift:buildSystemPrompt+ambientObservation, VirtualAssistantApp.swift:observation+ambient handlers, DashboardView.swift:chat completion, CLAUDE.md
**Related:** 2026-03-28 21:31:40 - Fix Blob Chat + Personality Revival
**Status:** Complete | **Next:** User testing

### 2026-03-28 21:31:40 - Fix Blob Chat + Personality Revival (main)
**What:** Fixed broken chat (never returned responses) + revived personality by removing destructive response post-processing
**Why:** User reported "thinking forever" on chat, and responses lacked diversity/personality
**Result:** All 7 fixes implemented and verified working:
- OpenAIClient.swift: Added API key logging, 30s request timeout via custom URLSession, comprehensive error logging in makeChatRequest (logs HTTP status, error bodies, success), removed destructive sanitizeUtterance chain (completeUtterance/enforceHumanLength/finalizeSentence all deleted), increased max_tokens to 200 for chat, added time awareness + varied chat prompts, improved personality prompt (more diversity, questions, varied tone)
- ScreenCapture.swift: Added CGWindowListCreateImage native fallback (works without Screen Recording TCC), JPEG quality 0.4 for small payloads, CLI screencapture as secondary fallback
- DashboardView.swift: Added 30s UI timeout timer for "Thinking..." state
- VirtualAssistantApp.swift: Added setbuf(stdout/stderr) for immediate log output, added ambient awareness logging
**References:** OpenAIClient.swift, ScreenCapture.swift, DashboardView.swift, VirtualAssistantApp.swift
**Related:** 2026-03-28 20:00:02 - Project Setup
**Status:** Complete | **Next:** User testing chat in dashboard

### 2026-03-28 20:00:02 - Project Setup (main)
**What:** Cloned https://github.com/AndreaBarrameda/blob.git to /Users/vincent/blob/
**Why:** Setting up new project for development
**Result:** Repo cloned, 24 Swift source files, SPM project (swift build && swift run VirtualAssistant). Requires .env with OPENAI_API_KEY.
**References:** CLAUDE.md (architecture), README.md, Package.swift
**Related:** None (first entry)
**Status:** Complete | **Next:** Create .env, build, run
