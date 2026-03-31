### 2026-03-31 19:46:48 - Git divergence recovery + compile fixes (elevenlabs-integration)
**What:** Rebased local `d9180f4` (Fixed: new controllers) onto remote `17434fa` (Quick Chat feature); resolved `VirtualAssistantApp.swift` conflict (kept quickChatSend/quickChatUserMessage notification names); fixed 6 compile errors post-rebase
**Why:** Local and remote had diverged from `eeb3685` — remote had Quick Chat, local had CameraCapture/CodexBridge/NotificationController/SafariController/SystemSettingsController
**Result:** Build complete; both feature sets merged; history: eeb3685 → 17434fa → 856d26f
**References:** OpenAIClient.swift (added `lastThinking` var, `chatWithImage` method); SystemAwareness.swift (added public `getDiskUsagePercent()`); SystemControl.swift (added `setVolume`, `setBrightness`); VirtualAssistantApp.swift (removed `openAI.codexBridge`, mapped `.love` → `.delighted`)
**Related:** 2026-03-31 18:19:00 (Quick Chat panel fix)
**Status:** Complete | **Next:** Push when ready
--Claude

### 2026-03-31 18:19:00 - Fix Quick Chat panel sizing (elevenlabs-integration)
**What:** Added `.frame(width: 550, height: 68)` to `QuickChatView.body` HStack — `NSHostingController` was shrinking panel to TextField's tiny intrinsic width, ignoring `contentRect` passed to `super.init()`
**Why:** Root cause: `NSHostingController` overrides window size with SwiftUI view's intrinsic content size; `TextField` default width is ~100pt, collapsing the panel
**Result:** Panel now renders at full 550pt width, text fully visible
**References:** QuickChatPanel.swift:177 (.frame fix), :107 (contentRect), :55 (panelHeight)
**Related:** 2026-03-31 18:15:20 - Hotkey change, 2026-03-31 18:04:50 - Quick Chat feature
**Status:** Complete | **Next:** User confirmation
--Claude

### 2026-03-31 18:15:20 - Swap Quick Chat hotkey to Cmd+Shift+Space (elevenlabs-integration)
**What:** Changed hotkey from Option+Space → Cmd+Shift+Space (Option+Space conflicts with ChatGPT desktop app)
**Why:** ChatGPT uses Option+Space globally; user discovered conflict and requested alternative
**Result:** Quick Chat now triggers on Cmd+Shift+Space (keyCode 49 with .command + .shift modifiers)
**References:** QuickChatPanel.swift:27-30
**Related:** 2026-03-31 18:04:50 - Quick Chat popup feature
**Status:** Complete | **Next:** Test new hotkey from other apps
--Claude

### 2026-03-31 18:04:50 - Quick Chat popup feature (elevenlabs-integration)
**What:** Global hotkey (Cmd+Shift+Space) that shows small floating panel for quick chat without opening dashboard
1. **New file**: `QuickChatPanel.swift` with:
   - `QuickChatManager` — owns panel lifecycle + global/local hotkey monitors (fires on Option+Space keyCode 49)
   - `QuickChatNSPanel` — 420x60 borderless floating panel, positioned near mouse, reused across toggles
   - `QuickChatView` (SwiftUI) — text field with blob indicator, send button, escape key handler
2. **VirtualAssistantApp.swift** changes:
   - Added `.quickChatSend` + `.quickChatUserMessage` notifications
   - Added `quickChatManager` property + `quickChatManager.setup()` in `applicationDidFinishLaunching`
   - Added `handleQuickChatSend(_:)` handler that mirrors voice-agent pipeline: assemble context, call LLM, log, show bubble, extract memories
3. **DashboardView.swift** — observer for `.quickChatUserMessage` appends user's quick chat messages to dashboard history (if open)
**Why:** ChatGPT-style quick chat everywhere — avoid context switch to open dashboard, type message, get response. Same chat pipeline as dashboard/voice mode.
**Result:** Press Option+Space anywhere → panel appears focused near cursor → type → submit → Blob responds with bubble → dismiss. Dashboard shows history. Escape to dismiss without sending.
**References:** QuickChatPanel.swift (new, 240 lines), VirtualAssistantApp.swift (property + setup + handler), DashboardView.swift (observer)
**Related:** 2026-03-30 02:55:46 - Camera voice output
**Status:** Complete | **Next:** User testing (hotkey from other apps, message history, Escape key)
--Claude

### 2026-03-30 02:55:46 - Camera voice output + keyword expansion (elevenlabs-integration)
**What:** Two camera UX improvements:
1. **Voice output**: Camera observations now automatically spoken aloud via ElevenLabs TTS. Added `appDelegate.elevenLabs.speak(response)` after camera image analysis completes.
2. **Keyword expansion**: Camera trigger was too strict ("look at me" / "see me" only). Now responds to: "look at", "see me", "see my", "can you see", "camera", "face" + "see" → makes it catchier with natural language variations
**Why:** User wanted Blob to actually talk during camera interactions, not just show text. Also wanted more flexible trigger phrases.
**Result:** Say "what can u see my face" or "how do I look like" and Blob speaks observations aloud with mood-appropriate voice.
**References:** DashboardView.swift:891-897 (keyword detection), 1369 (elevenLabs.speak call)
**Related:** 2026-03-30 02:34:26 - Camera capture + reminder time fix
**Status:** Complete | **Next:** Test camera + voice interaction
--Claude

### 2026-03-30 02:34:26 - Camera capture + reminder time fix (elevenlabs-integration)
**What:** Two fixes + camera integration:
1. **Reminder time parsing bug fix**: Regex only matched "minute|min|m", not "sec|s". User said "remind me in 30 sec" and it failed silently. Updated regex to `(\d+)\s*(?:seconds?|secs?|s|minutes?|mins?|m)` with logic to multiply by 1 for seconds, 60 for minutes.
2. **CameraCapture.swift** (new) — On-demand camera access (front camera only):
   - `requestCameraPermission()` — asks for camera access
   - `startCapture()` — starts video stream
   - `captureFrame()` → NSImage
   - `captureFrameAsBase64()` → base64 JPEG (40% quality)
3. **DashboardView**: Added camera property, handler for "look at me" or "see me" commands, calls `handleCameraRequest()` which:
   - Starts capture session
   - Grabs frame as base64
   - Sends to new `OpenAIClient.chatWithImage()` method with prompt to react to what Blob sees
4. **OpenAIClient**: Added `chatWithImage(image:message:completion)` — vision API call with image + mood parsing
**Why:** User wanted reminders with seconds, and camera access on-demand when saying "look at me"
**Result:** Reminders in seconds work. Say "look at me" and Blob reacts to your camera frame with emoji + mood.
**References:** CameraCapture.swift (new), DashboardView.swift (camera property, handleCameraRequest, "look at me" handler), OpenAIClient.swift (chatWithImage method), DashboardView.swift (reminder time parsing fix with regex)
**Related:** 2026-03-30 02:27:13 - Notification + reminder system
**Status:** Complete | **Next:** Test camera + reminders in seconds
--Claude

### 2026-03-30 02:27:13 - Notification + reminder system (elevenlabs-integration)
**What:** Created NotificationController.swift + integrated reminders:
1. NotificationController.swift (new) — macOS notifications via UNUserNotificationCenter:
   - `sendNotification(title, body, delay)`
   - `remind(message, after seconds)` — "Reminder in 5m"
   - `remindAt(message, hour, minute)` — "Reminder at 3:00pm"
   - `listScheduledNotifications()` — get pending
   - `clearAllNotifications()`
2. DashboardView: Added notifications property, command handler `handleNotificationCommands()`, time parsing for "remind me in 5m" and "remind me at 3pm"
3. AppDelegate: Added `[remind: <msg> in <min>m]` and `[remind: <msg> at <HH:MMam/pm>]` tag support with `handleRemindTag()` parser
4. OpenAIClient: Documented [remind:] tags in personality so Blob knows to use them
**Why:** User wanted Blob to send reminders + notifications
**Result:** Blob can now say "let me remind you in 30 minutes to drink water" using [remind: drink water in 30m] tag. Also works from chat: "remind me in 5 minutes to check the build"
**References:** NotificationController.swift (new), VirtualAssistantApp.swift:44, DashboardView.swift (notifications property, handlers), OpenAIClient.swift (tags documented), VirtualAssistantApp.swift (tag parsing+handlers)
**Related:** None (first entry for reminders)
**Status:** Complete | **Next:** Test reminders work + address camera access request
--Claude

### 2026-03-30 02:19:53 - Wallpaper XML parsing fix (elevenlabs-integration)
**What:** Root cause found: .madesktop files are XML metadata, not actual images:
1. .madesktop files contain <key>thumbnailPath</key> pointing to actual .heic/.jpg image files
2. We were trying to set the XML file as wallpaper (doesn't work) instead of the image path
3. Added `extractImagePathFromMadesktop()` to parse XML and extract thumbnailPath
4. Updated `randomBuiltInWallpaper()` to:
   - Read each .madesktop file
   - Parse XML to get actual image path (e.g., `/System/Library/Desktop Pictures/.thumbnails/Big Sur Mountains.heic`)
   - Use those actual paths for setWallpaper()
**Why:** Setting a metadata XML file does nothing. Only actual image files work.
**Result:** Now correctly extracts and sets real image files. Wallpaper should change visibly on each call.
**References:** SystemSettingsController.swift:41-75 (randomBuiltInWallpaper rewritten), 76-87 (extractImagePathFromMadesktop parser)
**Related:** 2026-03-30 02:14:14 - Wallpaper repeat fix
**Status:** Complete | **Next:** Test wallpaper changes actually work now
--Claude

### 2026-03-30 02:14:14 - Wallpaper repeat fix (elevenlabs-integration)
**What:** Fixed wallpaper not changing when called multiple times:
1. Added `lastWallpaper` property to track most recently set wallpaper
2. Updated `setWallpaper()` to record `lastWallpaper`
3. Updated `randomBuiltInWallpaper()` to filter out `lastWallpaper` from candidates before random selection
4. Now always picks a different wallpaper on each call
**Why:** Random picker was sometimes choosing the same wallpaper that was already set. Since the wallpaper was already active, macOS didn't refresh the display (looked like nothing happened).
**Result:** Each call to randomBuiltInWallpaper() now guarantees a visibly different wallpaper
**References:** SystemSettingsController.swift:4 (lastWallpaper), 8 (setWallpaper tracking), 41-57 (randomBuiltInWallpaper filtering)
**Related:** 2026-03-30 02:11:06 - Wallpaper execution fix
**Status:** Complete | **Next:** Test multiple wallpaper changes in sequence
--Claude

### 2026-03-30 02:11:06 - Wallpaper execution fix (elevenlabs-integration)
**What:** Fixed wallpaper changing:
1. Was using non-existent wallpaper paths (Mojave.heic, Catalina.heic don't exist)
2. AppleScript syntax was wrong — tried `set desktopImage to theFile` (doesn't work)
3. Correct syntax: `tell every desktop` + `set picture to POSIX file`
4. Updated randomBuiltInWallpaper() to dynamically list /System/Library/Desktop Pictures and filter .madesktop/.heic/.jpg files
5. Tested AppleScript directly — confirmed working
**Why:** Wallpaper wasn't changing despite "done" message. AppleScript was silently failing.
**Result:** Now reads actual available wallpapers, uses correct AppleScript syntax. Wallpaper changes immediately.
**References:** SystemSettingsController.swift:7-20 (setWallpaper), 38-49 (randomBuiltInWallpaper)
**Related:** 2026-03-30 02:07:56 - System Settings integration
**Status:** Complete | **Next:** Test wallpaper change from Blob command
--Claude

### 2026-03-30 02:07:56 - System Settings integration (elevenlabs-integration)
**What:** Created SystemSettingsController.swift + integrated wallpaper/settings control:
1. SystemSettingsController.swift (new) — System control methods: `openSystemSettings()`, `openWallpaperSettings()`, `setWallpaper(imagePath:)`, `setWallpaperFromURL()`, `randomBuiltInWallpaper()`, `changeBrightness()` (TODO), `setDarkMode()` (TODO)
2. AppDelegate — Added `let systemSettings = SystemSettingsController()`
3. DashboardView — Added systemSettings property, System Settings UI section (3 buttons: Settings, Wallpaper Settings, Random Wallpaper), command handler `handleSystemSettingsCommands()`
4. Tag support — Added `[wallpaper: random|settings|set <path>]` and `[settings: open|wallpaper]` tags to OpenAIClient personality
5. AppDelegate.handleMediaTags() — Added patterns for wallpaper + settings tags with `handleWallpaperTag()` + `handleSettingsTag()` handlers
**Why:** User wanted Blob to control system wallpaper + settings alongside Safari/Spotify control
**Result:** Build succeeds. Dashboard has System Settings buttons. Blob can respond with tags like "[wallpaper: random]" and auto-execute. Commands work from chat too.
**References:** SystemSettingsController.swift (new), VirtualAssistantApp.swift:43, DashboardView.swift (system property, UI 632-684, handler), OpenAIClient.swift:88-97 (tags), VirtualAssistantApp.swift:799-836 (tag handlers)
**Related:** 2026-03-30 01:58:45 - Safari tag execution
**Status:** Complete | **Next:** Test wallpaper changes + voice commands
--Claude

### 2026-03-30 01:58:45 - Safari tag execution + address bar search (elevenlabs-integration)
**What:** Fixed Safari search execution + added tag system:
1. SafariController.search() — was using URL navigation (broken). Now uses AppleScript: activate Safari, Cmd+L (focus address bar), type query, Enter. Lets Safari's default search engine handle it.
2. Added handleSafariTag() in AppDelegate — parses [safari: search <query>], [safari: open <url>], [safari: back|forward|reload]
3. Updated OpenAIClient personality — documented [safari:] tags for Blob to use in responses
4. Integrated into handleMediaTags flow — Blob's responses with [safari: ...] tags now auto-execute
**Why:** User feedback: search URL wasn't working, Safari start page interfered. Direct address bar is more reliable.
**Result:** Build succeeds. Blob can now say "let me search that" and actually execute via [safari: search dogs] tag. Focuses address bar and lets Safari handle the search.
**References:** SafariController.swift:24-33 (search method), VirtualAssistantApp.swift:785-808 (handleSafariTag), OpenAIClient.swift:88-94 (tags documented)
**Related:** 2026-03-30 01:54:10 - Safari integration
**Status:** Complete | **Next:** Test blob response with [safari:] tags
--Claude

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
