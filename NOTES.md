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
