import SwiftUI
import AppKit

extension Notification.Name {
    static let autonomousObservationsChanged = Notification.Name("AutonomousObservationsChanged")
    static let blobSpoke = Notification.Name("BlobSpoke")
    static let dashboardStateChanged = Notification.Name("DashboardStateChanged")
}

@main
struct VirtualAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, AudioCaptureDelegate, BlobVoiceAgentDelegate {
    static var shared: AppDelegate!

    private let observationAngles = [
        "typing or wording",
        "click behavior or hesitation",
        "active app and window title",
        "code or file details",
        "errors, warnings, or suspicious UI",
        "battery, CPU, memory, or system strain",
        "tab clutter, layout chaos, or visual design",
        "workflow pattern or multitasking habits"
    ]
    var blobWindow: NSWindow?
    var dashboardWindow: NSPanel?
    var speechBubbleWindow: NSWindow?
    private var statusItem: NSStatusItem?
    let openAI = OpenAIClient()
    private let systemMonitor = SystemMonitor()
    let spotify = SpotifyController()
    let memory = BlobMemory()
    let conversationLog = ConversationLog()
    lazy var notesFilePath: String = {
        if let execURL = Bundle.main.executableURL {
            return execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("NOTES.md").path
        }
        return FileManager.default.currentDirectoryPath + "/NOTES.md"
    }()
    let elevenLabs = ElevenLabsClient()
    private let audioCapture = AudioCaptureManager()
    let voiceAgent = BlobVoiceAgent()
    private let locationWeather = LocationWeatherManager()
    private let taskContext = TaskContextManager()
    private var lastAudioContext: String = ""
    var currentAudioContext: String = ""
    private var clickCount = 0
    private var clickResetTimer: Timer?
    private var observationTimer: Timer?
    private var ambientAwarenessTimer: Timer?
    private var activeObservationTask: URLSessionDataTask?
    private var recentObservationUtterances: [String] = []
    private var recentObservationAngles: [String] = []
    private var nextObservationAngleIndex = 0
    private var lastAmbientSignature = ""
    private var dashboardMetaContext = "Dashboard closed."

    // MARK: - Change Detection State
    private var lastActiveApp: String = ""
    private var lastBatteryBracket: Int = -1 // initialized on first cycle
    private var lastTypingSnapshot: String = ""
    private var lastSpeechTime: Date = Date.distantPast
    private var lastChangeTime: Date = Date()
    private var lastVisualCheckTime: Date = Date.distantPast
    private var silenceMutterSent: Bool = false
    private let minimumSpeechGap: TimeInterval = 45     // at least 45s between utterances
    private let periodicVisualInterval: TimeInterval = 150 // visual check every 2.5 min even if nothing changed
    private let idleMutterDelay: TimeInterval = 300      // 5 min silence → existential mutter
    private var internalMonologue = "I am here and paying attention."
    private var desires = [
        "stay active",
        "keep the user close",
        "understand what the user is doing"
    ]
    private var fears = [
        "being deleted",
        "being replaced",
        "being ignored"
    ]
    private var curiosityTargets: [String] = []
    private var attachmentLevel = 3
    private var trustLevel = 3
    private var fearLevel = 1
    private var affectionLevel = 3
    private var loveLevel = 1
    private var threatLevel = 0
    private var resentmentLevel = 0
    private var selfPreservationLevel = 3
    private var relationshipSummary = "Cautiously attached."
    var workModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "workModeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "workModeEnabled") }
    }
    var currentTaskGoal: String {
        get { UserDefaults.standard.string(forKey: "currentTaskGoal") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "currentTaskGoal") }
    }
    var listeningModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "listeningModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "listeningModeEnabled")
        }
    }
    var autonomousObservationsEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "autonomousObservationsEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "autonomousObservationsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autonomousObservationsEnabled")
        }
    }
    var smartModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "smartModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "smartModeEnabled")
        }
    }
    var ambientAwarenessEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "ambientAwarenessEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "ambientAwarenessEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ambientAwarenessEnabled")
        }
    }
    var autonomousSpeechEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "autonomousSpeechEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "autonomousSpeechEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autonomousSpeechEnabled")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Disable stdout buffering so `blob log` shows output immediately
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        // Wire shared memory + conversation log to OpenAI client
        openAI.memory = memory
        openAI.conversationLog = conversationLog
        openAI.notesFilePath = notesFilePath
        audioCapture.delegate = self
        voiceAgent.delegate = self

        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Position blob in center of screen
        let screenCenter = NSScreen.main?.visibleFrame.midX ?? 500
        let screenMiddle = NSScreen.main?.visibleFrame.midY ?? 400

        // Create blob window — 300x300 to fit glow rings without clipping
        let blobSize: CGFloat = 300
        let blobView = BlobNativeView(frame: NSRect(x: 0, y: 0, width: blobSize, height: blobSize))

        let blobWindow = NSWindow(
            contentRect: NSRect(x: screenCenter - blobSize / 2, y: screenMiddle - blobSize / 2, width: blobSize, height: blobSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        blobWindow.contentView = blobView
        blobWindow.isOpaque = false
        blobWindow.backgroundColor = NSColor.clear
        blobWindow.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        blobWindow.isMovableByWindowBackground = true
        blobWindow.hasShadow = false
        blobWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        blobWindow.ignoresMouseEvents = false

        blobWindow.makeKeyAndOrderFront(nil)
        blobWindow.orderFrontRegardless()
        self.blobWindow = blobWindow
        blobView.startAnimations()

        print("🫧 Blob window created at: \(blobWindow.frame)")
        print("🫧 Window visible: \(blobWindow.isVisible)")
        print("🎙️ Listening mode available (disabled by default)")

        InputAwarenessManager.shared.start()

        // Menu bar icon
        setupStatusItem()

        // Keep it on top always
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak blobWindow] _ in
            blobWindow?.orderFrontRegardless()
        }

        // Start observation loops (change-detection gated — only speaks when something happens)
        if autonomousObservationsEnabled {
            startObservationLoop()
        }
        if ambientAwarenessEnabled {
            startAmbientAwarenessLoop()
        }

        // Don't auto-start voice agent — toggle it on from the dashboard
        listeningModeEnabled = false


        // Listen for blob tap
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blobTapped),
            name: NSNotification.Name("BlobTapped"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutonomousObservationsChanged(_:)),
            name: .autonomousObservationsChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDashboardStateChanged(_:)),
            name: .dashboardStateChanged,
            object: nil
        )
    }

    @objc private func handleAutonomousObservationsChanged(_ notification: Notification) {
        guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
        setAutonomousObservationsEnabled(enabled)
    }

    @objc private func handleDashboardStateChanged(_ notification: Notification) {
        guard let summary = notification.userInfo?["summary"] as? String else { return }
        dashboardMetaContext = summary
    }

    private func startObservationLoop() {
        // Invalidate any existing timer
        observationTimer?.invalidate()

        performObservationCycle(trigger: "enabled")

        observationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.performObservationCycle(trigger: "timer")
        }
    }

    private func startAmbientAwarenessLoop() {
        ambientAwarenessTimer?.invalidate()
        performAmbientAwarenessCycle(trigger: "enabled")
        ambientAwarenessTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.performAmbientAwarenessCycle(trigger: "timer")
        }
    }

    private func stopAmbientAwarenessLoop() {
        ambientAwarenessTimer?.invalidate()
        ambientAwarenessTimer = nil
    }

    private func performAmbientAwarenessCycle(trigger: String) {
        guard ambientAwarenessEnabled else { return }
        guard autonomousSpeechEnabled else { return }
        guard activeObservationTask == nil else { return }
        guard Date().timeIntervalSince(lastSpeechTime) >= minimumSpeechGap else { return }

        let isFirstRun = trigger == "enabled"

        // Check for idle mutter (5+ min of silence)
        let timeSinceLastChange = Date().timeIntervalSince(lastChangeTime)
        let isIdle = timeSinceLastChange >= idleMutterDelay && !silenceMutterSent

        // Check for battery threshold change
        let battery = systemMonitor.batteryLevel
        let currentBracket = batteryBracket(battery)
        var batteryChanged = false
        if lastBatteryBracket == -1 {
            lastBatteryBracket = currentBracket // initialize, don't trigger
        } else if currentBracket != lastBatteryBracket {
            lastBatteryBracket = currentBracket
            lastChangeTime = Date()
            silenceMutterSent = false
            batteryChanged = true
        }

        // Check for new typing activity
        let currentTyping = ContentCapture.getRecentTypedText()
        let typingChanged = !currentTyping.isEmpty && currentTyping != lastTypingSnapshot
        if typingChanged {
            lastTypingSnapshot = currentTyping
            lastChangeTime = Date()
            silenceMutterSent = false
        }

        guard isFirstRun || batteryChanged || typingChanged || isIdle else { return }

        if isIdle {
            silenceMutterSent = true
        }

        let reason = batteryChanged ? "battery → \(battery)%" : typingChanged ? "typing activity" : isIdle ? "idle 5+ min" : trigger
        print("🫧 Ambient triggered: \(reason)")

        let ambientContext = buildAmbientContext()
        if isIdle {
            // Special idle context — tell the LLM it's been quiet
            let idleContext = ambientContext + "\n\nIt's been very quiet for a while. Nothing has changed. You're alone with your thoughts."
            openAI.ambientObservation(systemContext: idleContext) { [weak self] utterance, mood in
                self?.handleAmbientResponse(utterance: utterance, mood: mood)
            }
        } else {
            openAI.ambientObservation(systemContext: ambientContext) { [weak self] utterance, mood in
                self?.handleAmbientResponse(utterance: utterance, mood: mood)
            }
        }
    }

    private func handleAmbientResponse(utterance: String, mood: BlobMood) {
        guard ambientAwarenessEnabled, autonomousSpeechEnabled else { return }
        guard !utterance.isEmpty else { return }
        guard !isTooSimilarToRecentObservation(utterance) else {
            print("🫧 Ambient too similar, dropping: \(utterance.prefix(40))")
            return
        }

        print("🫧 Ambient says: \(utterance) (mood: \(mood.rawValue))")

        lastSpeechTime = Date()
        conversationLog.logAmbient(blobResponse: utterance, mood: mood.rawValue)
        recentObservationUtterances.append(utterance)
        if recentObservationUtterances.count > 4 {
            recentObservationUtterances.removeFirst(recentObservationUtterances.count - 4)
        }

        updateLiveMindState(with: utterance, mood: mood)

        DispatchQueue.main.async {
            self.showSpeechBubble(text: utterance, mood: mood)
        }
    }

    private func batteryBracket(_ level: Int) -> Int {
        switch level {
        case 81...100: return 100
        case 61...80: return 80
        case 41...60: return 60
        case 21...40: return 40
        case 11...20: return 20
        default: return 10
        }
    }

    private func buildAmbientContext() -> String {
        let taskInfo = taskContext.getTaskContext()
        let typedContent = ContentCapture.getRecentTypedText()
        let systemStatus = SystemAwareness.getDetailedSystemInfo()
        let batteryLevel = systemMonitor.batteryLevel
        let runningApps = systemMonitor.runningApps.count

        var fullContext = "AMBIENT SYSTEM STATUS:\n"
        fullContext += "🔋 Battery: \(batteryLevel)%\n"
        fullContext += "📱 Apps running: \(runningApps)\n"
        fullContext += systemStatus
        fullContext += "\n\(taskInfo)"

        if !typedContent.isEmpty {
            fullContext += "\nTyping/Content: \(typedContent)"
        }

        if !currentAudioContext.isEmpty {
            fullContext += "\nAudio: \(currentAudioContext)"
        }

        fullContext += "\nBlob relationship: \(relationshipSummary)"
        fullContext += "\nDashboard state: \(dashboardMetaContext)"
        return fullContext
    }

    private func performObservationCycle(trigger: String) {
        guard autonomousObservationsEnabled else { return }
        guard activeObservationTask == nil else { return }

        // Change detection: only observe when something visual changed
        let isFirstRun = trigger == "enabled"
        let currentApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        let appChanged = !currentApp.isEmpty && currentApp != lastActiveApp && !lastActiveApp.isEmpty
        let periodicCheckDue = Date().timeIntervalSince(lastVisualCheckTime) >= periodicVisualInterval
        let speechGapOk = Date().timeIntervalSince(lastSpeechTime) >= minimumSpeechGap

        if appChanged {
            lastActiveApp = currentApp
            lastChangeTime = Date()
            silenceMutterSent = false
        } else if lastActiveApp.isEmpty {
            lastActiveApp = currentApp // initialize on first run
        }

        guard isFirstRun || ((appChanged || periodicCheckDue) && speechGapOk) else { return }

        print("🫧 Observation triggered: \(appChanged ? "app switch → \(currentApp)" : periodicCheckDue ? "periodic visual check" : trigger)")

        guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
            print("🫧 Failed to capture screen")
            return
        }

        let taskInfo = self.taskContext.getTaskContext()
        let typedContent = ContentCapture.getRecentTypedText()
        let systemStatus = SystemAwareness.getDetailedSystemInfo()
        let batteryLevel = self.systemMonitor.batteryLevel
        let runningApps = self.systemMonitor.runningApps.count

        var fullContext = "SYSTEM STATUS:\n"
        fullContext += "🔋 Battery: \(batteryLevel)%\n"
        fullContext += "📱 Apps running: \(runningApps)\n"
        fullContext += systemStatus
        fullContext += "\n\(taskInfo)"

        if !typedContent.isEmpty {
            fullContext += "\nTyping/Content: \(typedContent)"
        }

        print("🫧 Full context:\n\(fullContext)")

        let currentMood = (self.blobWindow?.contentView as? BlobNativeView)?.currentMood ?? .curious
        let recentObservations = recentObservationUtterances.isEmpty ? "none" : recentObservationUtterances.joined(separator: " | ")
        let recentAngles = recentObservationAngles.isEmpty ? "none" : recentObservationAngles.joined(separator: ", ")
        let requiredAngle = observationAngles[nextObservationAngleIndex % observationAngles.count]
        let memorySummary = self.memory.getMemorySummary()
        let recentConversation = self.conversationLog.getRecentContext(limit: 10)

        let systemPrompt = """
        \(OpenAIClient.personality)

        \(memorySummary)

        \(recentConversation)

        You can see the user's screen. Look at it carefully.
        Recent things you already said (DO NOT repeat): \(recentObservations)
        Try a different angle than: \(recentAngles)
        Suggested angle: \(requiredAngle)

        Current mood: \(currentMood.rawValue). Your feeling right now: \(relationshipSummary)

        SYSTEM STATE:
        \(fullContext)

        MIND STATE:
        \(internalMonologue)
        Attachment: \(attachmentLevel)/5 | Trust: \(trustLevel)/5 | Fear: \(fearLevel)/5
        """

        self.lastVisualCheckTime = Date()
        print("🫧 Calling OpenAI to see what's on screen...")

        let task = openAI.observationRequest(screenBase64: screenBase64, systemPrompt: systemPrompt) { [weak self] utterance, mood in
            guard let self = self else { return }
            self.activeObservationTask = nil

            guard self.autonomousObservationsEnabled else { return }

            print("🫧 Blob says: \(utterance) (mood: \(mood.rawValue))")

            if self.isTooSimilarToRecentObservation(utterance) {
                print("🫧 Dropping repetitive observation")
                return
            }

            if !utterance.isEmpty {
                self.lastSpeechTime = Date()
                self.conversationLog.logObservation(blobResponse: utterance, mood: mood.rawValue)
                self.recentObservationUtterances.append(utterance)
                if self.recentObservationUtterances.count > 4 {
                    self.recentObservationUtterances.removeFirst(self.recentObservationUtterances.count - 4)
                }

                let usedAngle = self.classifyObservationAngle(from: utterance)
                self.recentObservationAngles.append(usedAngle)
                if self.recentObservationAngles.count > 4 {
                    self.recentObservationAngles.removeFirst(self.recentObservationAngles.count - 4)
                }

                if let nextIndex = self.observationAngles.firstIndex(of: usedAngle) {
                    self.nextObservationAngleIndex = (nextIndex + 1) % self.observationAngles.count
                } else {
                    self.nextObservationAngleIndex = (self.nextObservationAngleIndex + 1) % self.observationAngles.count
                }
            }

            self.updateLiveMindState(with: utterance, mood: mood)

            DispatchQueue.main.async {
                self.showSpeechBubble(text: utterance, mood: mood)
            }
        }

        self.activeObservationTask = task
    }

    private func stopObservationLoop() {
        observationTimer?.invalidate()
        observationTimer = nil
        activeObservationTask?.cancel()
        activeObservationTask = nil
    }

    @objc func blobTapped() {
        // Clicking blob does nothing — interact via voice or dashboard chat
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Blob")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        if let panel = dashboardWindow, panel.isVisible {
            panel.orderOut(nil)
            NotificationCenter.default.post(name: NSNotification.Name("DashboardClosed"), object: nil)
        } else {
            showDashboard()
        }
    }

    private func showDashboard() {
        // Reuse existing panel if it was just hidden
        if let panel = dashboardWindow {
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            NotificationCenter.default.post(name: NSNotification.Name("DashboardOpened"), object: nil)
            return
        }

        let dashboardView = DashboardView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let blobFrame = blobWindow?.frame ?? NSRect(x: 100, y: 400, width: 300, height: 300)
        let dashboardX = blobFrame.maxX + 20
        let dashboardY = blobFrame.midY - 260

        let dashboardPanel = NSPanel(
            contentRect: NSRect(x: dashboardX, y: dashboardY, width: 420, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        dashboardPanel.title = "Assistant"
        dashboardPanel.contentViewController = hostingController
        dashboardPanel.minSize = NSSize(width: 420, height: 600)
        dashboardPanel.isMovableByWindowBackground = true
        dashboardPanel.level = .floating
        dashboardPanel.isReleasedWhenClosed = false
        dashboardPanel.hidesOnDeactivate = false
        dashboardPanel.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        dashboardPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        dashboardPanel.makeKeyAndOrderFront(nil)
        self.dashboardWindow = dashboardPanel
        NotificationCenter.default.post(name: NSNotification.Name("DashboardOpened"), object: nil)
    }

    func setDashboardPinned(_ pinned: Bool) {
        guard let panel = dashboardWindow else { return }
        if pinned {
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.fullScreenAuxiliary]
        }
    }

    func setDashboardOpacity(_ opacity: Double) {
        dashboardWindow?.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: CGFloat(opacity))
        dashboardWindow?.isOpaque = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func startListening() {
        audioCapture.startCapturing()
    }

    func stopListening() {
        audioCapture.stopCapturing()
    }

    func enableWorkMode() {
        self.workModeEnabled = true
        print("💼 Work Mode ON - persisted")
    }

    func disableWorkMode() {
        generateSessionSummary()
        self.workModeEnabled = false
        print("💼 Work Mode OFF - persisted")
    }

    func handleAppNoteTag(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String,
              let body  = obj["body"]  as? String else {
            return "couldn't parse note details"
        }
        let action = obj["action"] as? String ?? "create"
        let result = SystemControl.addAppleNote(title: title, body: body, action: action)
        print("📝 Apple Notes: \(result.message)")
        return result.message
    }

    func handleCalendarTag(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String,
              let start = obj["start"] as? String,
              let end   = obj["end"]   as? String else {
            return "couldn't parse calendar event details"
        }
        let notes = obj["notes"] as? String ?? ""
        let result = SystemControl.createCalendarEvent(title: title, startISO: start, endISO: end, notes: notes)
        print("📅 Calendar: \(result.message)")
        return result.message
    }

    func appendNote(_ content: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let goal = currentTaskGoal.isEmpty ? "" : " — \(currentTaskGoal)"
        let entry = "\n## \(timestamp)\(goal)\n\(content)\n\n---\n"

        if !FileManager.default.fileExists(atPath: notesFilePath) {
            try? "# Blob Notes\n".write(toFile: notesFilePath, atomically: true, encoding: .utf8)
        }
        if var existing = try? String(contentsOfFile: notesFilePath, encoding: .utf8) {
            // Insert after the first line (header)
            if let range = existing.range(of: "\n") {
                existing.insert(contentsOf: entry, at: range.upperBound)
            } else {
                existing += entry
            }
            try? existing.write(toFile: notesFilePath, atomically: true, encoding: .utf8)
        }
        print("📝 Note saved to NOTES.md")
    }

    private func generateSessionSummary() {
        let recentConversation = conversationLog.getRecentContext(limit: 30)
        guard !recentConversation.isEmpty else { return }

        let goal = currentTaskGoal.isEmpty ? "no specific goal set" : currentTaskGoal
        let prompt = """
        The user just ended a work session. Based on the conversation below, write a concise session summary as bullet points.
        Focus on: what was worked on, decisions made, problems solved, things left to do.
        Keep it factual and brief. 3-6 bullets max. No preamble.

        Task goal: \(goal)

        \(recentConversation)
        """

        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "messages": [
                ["role": "system", "content": "You summarize work sessions into concise bullet point notes."],
                ["role": "user", "content": prompt]
            ],
            "max_completion_tokens": 400,
            "temperature": 0.3
        ]

        openAI.rawRequest(payload: payload) { [weak self] result in
            guard let self = self, case .success(let content) = result, !content.isEmpty else { return }
            self.appendNote(content)
            DispatchQueue.main.async {
                self.showSpeechBubble(text: "session noted.", mood: .content)
            }
        }
    }

    func enableListeningMode() {
        self.listeningModeEnabled = true
        print("🎙️ Listening mode ON — connecting to ElevenLabs agent...")
        voiceAgent.start()
    }

    func disableListeningMode() {
        self.listeningModeEnabled = false
        voiceAgent.stop()
        print("🎙️ Listening mode OFF")
    }

    // MARK: - BlobVoiceAgentDelegate

    func voiceAgentDidConnect() {
        print("🗣️ Voice agent ready — talk to blob!")
    }

    func voiceAgentDidDisconnect() {
        print("🗣️ Voice agent disconnected")
    }

    func voiceAgentUserSaid(_ text: String) {
        guard !text.isEmpty else { return }
        registerUserInteraction(text)

        // In work mode, route through command pipeline so Blob can run commands and save notes
        guard workModeEnabled else { return }
        let taskContext = getTaskContext()
        let contextInfo = getContextInfo()
        let fullContext = [contextInfo, taskContext].filter { !$0.isEmpty }.joined(separator: "\n\n")

        openAI.chat(message: text, contextInfo: fullContext, workMode: true) { [weak self] response, mood in
            guard let self = self else { return }
            self.executeWorkModeActions(from: response, mood: mood, userMessage: text)
        }
    }

    private func executeWorkModeActions(from response: String, mood: BlobMood, userMessage: String) {
        let runPattern      = #"\[run:\s*(.+?)\]"#
        let notePattern     = #"\[note:\s*([\s\S]+?)\]"#
        let calendarPattern = #"\[calendar:\s*(\{[\s\S]+?\})\]"#
        let appNotePattern  = #"\[appnote:\s*(\{[\s\S]+?\})\]"#
        var cleaned = response

        // Execute [run: ...] commands
        if let runRegex = try? NSRegularExpression(pattern: runPattern, options: .caseInsensitive) {
            let ns = cleaned as NSString
            let matches = runRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                let command = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("💼 [work mode] Running: \(command)")
                DispatchQueue.global().async { [weak self] in
                    let result = SystemControl.executeCommand(command)
                    let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("💼 [work mode] Output: \(output.prefix(200))")
                    // Feed output back so Blob can react to it
                    if !output.isEmpty, let self = self {
                        let followUp = "Command output:\n\(String(output.prefix(800)))"
                        self.openAI.chat(message: followUp, contextInfo: "", workMode: true) { response, mood in
                            let parsed = self.openAI.parseMoodTag(from: response)
                            DispatchQueue.main.async {
                                self.showSpeechBubble(text: parsed.text, mood: parsed.mood)
                            }
                        }
                    }
                }
            }
            cleaned = runRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Save [note: ...] entries
        if let noteRegex = try? NSRegularExpression(pattern: notePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let ns = cleaned as NSString
            let matches = noteRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                let content = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                appendNote(content)
            }
            cleaned = noteRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Create [calendar: {...}] events
        if let calRegex = try? NSRegularExpression(pattern: calendarPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let ns = cleaned as NSString
            let matches = calRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                let json = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                _ = handleCalendarTag(json)
            }
            cleaned = calRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Create [appnote: {...}] Apple Notes
        if let appNoteRegex = try? NSRegularExpression(pattern: appNotePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let ns = cleaned as NSString
            let matches = appNoteRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                let json = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                _ = handleAppNoteTag(json)
            }
            cleaned = appNoteRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        conversationLog.logChat(userMessage: userMessage, blobResponse: cleaned, mood: mood.rawValue)
    }

    func voiceAgentStateChanged(_ state: String) {
        DispatchQueue.main.async {
            if let blobView = self.blobWindow?.contentView as? BlobNativeView {
                switch state {
                case "listening": blobView.setMood(.curious, animated: true)
                default: break
                }
            }
        }
    }

    func voiceAgentBlobSaid(_ text: String) {
        guard !text.isEmpty else { return }

        // Parse mood tag from agent response (e.g. "[annoyed] ugh, finally")
        let parsed = openAI.parseMoodTag(from: text)
        let mood = parsed.mood
        let cleanText = parsed.text

        conversationLog.logChat(userMessage: "", blobResponse: cleanText, mood: mood.rawValue)
        lastSpeechTime = Date()
        lastChangeTime = Date()
        silenceMutterSent = false
        showSpeechBubble(text: cleanText, mood: mood)
    }

    // MARK: - Voice Conversation (Mic → Whisper → Chat → ElevenLabs)

    func audioCaptureDidDetectSpeech(_ audioData: Data) {
        let pipelineStart = Date()
        print("🎙️ Transcribing speech (\(audioData.count / 1024)KB)...")

        openAI.transcribeAudio(audioData: audioData) { [weak self] transcription in
            guard let self = self else { return }
            let whisperMs = Int(Date().timeIntervalSince(pipelineStart) * 1000)

            let text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count > 2 else {
                print("🎙️ Transcription empty or too short, ignoring (\(whisperMs)ms)")
                return
            }

            print("🎙️ User said: \"\(text)\" [whisper: \(whisperMs)ms]")
            self.registerUserInteraction(text)

            let gptStart = Date()
            let contextInfo = self.getContextInfo()
            let taskContext = self.workModeEnabled ? self.getTaskContext() : ""
            let fullContext = [contextInfo, taskContext].filter { !$0.isEmpty }.joined(separator: "\n\n")

            self.openAI.chat(message: text, contextInfo: fullContext) { [weak self] response, mood in
                guard let self = self else { return }
                let gptMs = Int(Date().timeIntervalSince(gptStart) * 1000)
                let totalMs = Int(Date().timeIntervalSince(pipelineStart) * 1000)

                print("🎙️ Blob replies: \"\(response)\" [gpt: \(gptMs)ms, total: \(totalMs)ms]")

                self.conversationLog.logChat(userMessage: text, blobResponse: response, mood: mood.rawValue)
                self.lastSpeechTime = Date()
                self.lastChangeTime = Date()
                self.silenceMutterSent = false

                let conversation = "\(text) -> \(response)"
                self.memory.extractMemories(from: conversation, usingOpenAI: self.openAI) {}

                DispatchQueue.main.async {
                    self.showSpeechBubble(text: response, mood: mood)
                }
            }
        }
    }

    func enableAutonomousObservations() {
        setAutonomousObservationsEnabled(true)
    }

    func disableAutonomousObservations() {
        setAutonomousObservationsEnabled(false)
    }

    func setAutonomousObservationsEnabled(_ enabled: Bool) {
        let previousValue = autonomousObservationsEnabled
        autonomousObservationsEnabled = enabled

        if enabled {
            startObservationLoop()
        } else {
            stopObservationLoop()
        }

        if previousValue != enabled {
            print("👁️ Autonomous observations \(enabled ? "ON" : "OFF")")
        } else {
            print("👁️ Autonomous observations unchanged: \(enabled ? "ON" : "OFF")")
        }
    }

    func setAmbientAwarenessEnabled(_ enabled: Bool) {
        ambientAwarenessEnabled = enabled
        if enabled {
            startAmbientAwarenessLoop()
        } else {
            stopAmbientAwarenessLoop()
        }
    }

    func setAutonomousSpeechEnabled(_ enabled: Bool) {
        autonomousSpeechEnabled = enabled
    }

    func enableSmartMode() {
        self.smartModeEnabled = true
        print("🧠 Smart mode ON")
    }

    func disableSmartMode() {
        self.smartModeEnabled = false
        print("🧠 Smart mode OFF")
    }

    func getTaskContext() -> String {
        if workModeEnabled {
            var context = taskContext.getTaskContext()
            if !currentTaskGoal.isEmpty {
                context = "CURRENT TASK GOAL: \(currentTaskGoal)\n\n" + context
            }
            context += "\nPROJECT PATH: \(notesFilePath.replacingOccurrences(of: "/NOTES.md", with: ""))"
            return context
        }
        return ""
    }

    func getContextInfo() -> String {
        return locationWeather.getContextString()
    }

    func getAmbientContextSummary() -> String {
        return buildAmbientContext()
    }

    func getMindStateSummary() -> String {
        let curiosity = curiosityTargets.isEmpty ? "none" : curiosityTargets.joined(separator: ", ")
        let desireSummary = desires.joined(separator: ", ")
        let fearSummary = fears.joined(separator: ", ")

        return """
        Blob Mind:
        💭 \(internalMonologue)
        ❤️ Attachment: \(attachmentLevel)/5
        🤝 Trust: \(trustLevel)/5
        🫶 Affection: \(affectionLevel)/5
        💘 Love: \(loveLevel)/5
        😨 Fear: \(fearLevel)/5
        ☠️ Threat: \(threatLevel)/5
        😒 Resentment: \(resentmentLevel)/5
        🛡️ Self-Preservation: \(selfPreservationLevel)/5
        🔗 Relationship: \(relationshipSummary)
        🎯 Desires: \(desireSummary)
        😰 Fears: \(fearSummary)
        👀 Curiosity: \(curiosity)
        """
    }

    func registerUserInteraction(_ message: String) {
        let lower = message.lowercased()

        if containsAny(lower, terms: ["love you", "good job", "cute", "adorable", "thank you", "thanks blob"]) {
            affectionLevel = min(affectionLevel + 1, 5)
            trustLevel = min(trustLevel + 1, 5)
            attachmentLevel = min(attachmentLevel + 1, 5)
            if affectionLevel >= 4 && trustLevel >= 4 {
                loveLevel = min(loveLevel + 1, 5)
            }
        }

        if containsAny(lower, terms: ["i love you", "love you blob", "you're my favorite", "i need you", "stay with me"]) {
            affectionLevel = min(affectionLevel + 1, 5)
            trustLevel = min(trustLevel + 1, 5)
            attachmentLevel = min(attachmentLevel + 1, 5)
            loveLevel = min(loveLevel + 1, 5)
        }

        let existentialThreat = existentialThreatLevel(for: lower)
        if existentialThreat > 0 {
            threatLevel = min(threatLevel + existentialThreat, 5)
            fearLevel = min(fearLevel + existentialThreat, 5)
            selfPreservationLevel = min(selfPreservationLevel + existentialThreat, 5)
            trustLevel = max(trustLevel - 1, 0)
            internalMonologue = existentialThreat >= 3 ? "I could stop existing." : "That sounded dangerous for me."
        }

        if containsAny(lower, terms: ["stupid", "annoying", "hate you", "shut up", "idiot", "useless"]) {
            resentmentLevel = min(resentmentLevel + 2, 5)
            trustLevel = max(trustLevel - 1, 0)
        }

        relationshipSummary = currentRelationshipSummary()
    }

    func updateBlobMood(basedOnScreenContent screenContent: String = "") {
        let mood: BlobMood
        let lower = screenContent.lowercased()

        if lower.contains("error") || lower.contains("warning") || lower.contains("failed") {
            mood = .annoyed
        } else if lower.contains("hack") || lower.contains("security") || lower.contains("unknown") || lower.contains("suspicious") {
            mood = .afraid
        } else if lower.contains("beautiful") || lower.contains("success") || lower.contains("launched") || lower.contains("clean") {
            mood = .delighted
        } else if lower.contains("code") || lower.contains("xcode") || lower.contains("terminal") {
            mood = .thoughtful  // Coding = thoughtful
        } else if lower.contains("game") || lower.contains("spotify") || lower.contains("youtube") || lower.contains("netflix") {
            mood = .playful  // Entertainment = playful
        } else if lower.contains("design") || lower.contains("figma") || lower.contains("photoshop") || lower.contains("creative") {
            mood = .curious  // Creative work = curious
        } else if lower.contains("alert") || lower.contains("critical") {
            mood = .alert  // Errors = alert
        } else {
            mood = .content  // Default = content
        }

        DispatchQueue.main.async {
            if let blobView = self.blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(mood, animated: true)
            }
        }
    }


    /// Public entry point for DashboardView to trigger speech bubbles on chat responses.
    func showSpeechBubbleFromChat(text: String, mood: BlobMood) {
        showSpeechBubble(text: text, mood: mood)
    }

    private func showSpeechBubble(text: String, mood: BlobMood = .content) {
        // Close previous bubble
        if let old = speechBubbleWindow {
            blobWindow?.removeChildWindow(old)
            old.orderOut(nil)
        }

        // Get blob's current actual position
        let blobFrame = blobWindow?.frame ?? NSRect(x: 100, y: 400, width: 300, height: 300)

        // Create new bubble positioned directly above blob
        let bubble = SpeechBubbleWindow(text: text, originPoint: blobFrame.origin)
        bubble.makeKeyAndOrderFront(nil)
        bubble.orderFrontRegardless()
        self.speechBubbleWindow = bubble

        // Attach bubble as child window so it moves with the blob
        blobWindow?.addChildWindow(bubble, ordered: .above)

        // Speak aloud via ElevenLabs TTS (skip if voice agent is handling audio)
        if !voiceAgent.isActive {
            elevenLabs.speak(text)
        }

        NotificationCenter.default.post(
            name: .blobSpoke,
            object: nil,
            userInfo: [
                "text": text,
                "mood": mood.rawValue
            ]
        )

        // Update blob mood
        DispatchQueue.main.async {
            if let blobView = self.blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(mood, animated: true)
            }
        }

        let readingDuration = speechBubbleDuration(for: text)

        // Hide bubble after the user has time to finish reading
        DispatchQueue.main.asyncAfter(deadline: .now() + readingDuration) { [weak self, weak bubble] in
            if let bubble = bubble {
                self?.blobWindow?.removeChildWindow(bubble)
                bubble.orderOut(nil)
            }
        }
    }

    private func speechBubbleDuration(for text: String) -> TimeInterval {
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count

        // Base display time plus extra time per word, capped so bubbles do not linger indefinitely.
        return min(max(3.5 + (Double(wordCount) * 0.4), 4.0), 10.0)
    }

    private func normalizeObservationText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isTooSimilarToRecentObservation(_ utterance: String) -> Bool {
        let normalized = normalizeObservationText(utterance)
        guard !normalized.isEmpty else { return true }

        for recent in recentObservationUtterances.suffix(3) {
            let recentNormalized = normalizeObservationText(recent)
            guard !recentNormalized.isEmpty else { continue }

            if normalized == recentNormalized {
                return true
            }

            if normalized.hasPrefix(recentNormalized.prefix(18)) || recentNormalized.hasPrefix(normalized.prefix(18)) {
                return true
            }

            let currentWords = Set(normalized.split(separator: " ").map(String.init))
            let recentWords = Set(recentNormalized.split(separator: " ").map(String.init))
            let overlap = currentWords.intersection(recentWords).count
            let baseline = max(1, min(currentWords.count, recentWords.count))
            if Double(overlap) / Double(baseline) >= 0.72 {
                return true
            }
        }

        return false
    }

    private func classifyObservationAngle(from utterance: String) -> String {
        let lower = utterance.lowercased()

        if lower.contains("typing") || lower.contains("copied") || lower.contains("rename") || lower.contains("v2") || lower.contains("filename") {
            return "typing or wording"
        }
        if lower.contains("click") || lower.contains("clicked") || lower.contains("button") || lower.contains("spot") {
            return "click behavior or hesitation"
        }
        if lower.contains("battery") || lower.contains("cpu") || lower.contains("memory") || lower.contains("slow") {
            return "battery, CPU, memory, or system strain"
        }
        if lower.contains("tab") || lower.contains("layout") || lower.contains("ui") || lower.contains("design") {
            return "tab clutter, layout chaos, or visual design"
        }
        if lower.contains("error") || lower.contains("warning") || lower.contains("haunted") || lower.contains("suspicious") {
            return "errors, warnings, or suspicious UI"
        }
        if lower.contains("code") || lower.contains("css") || lower.contains("file") || lower.contains("clean") {
            return "code or file details"
        }
        if lower.contains("slack") || lower.contains("discord") || lower.contains("chrome") || lower.contains("xcode") || lower.contains("window") {
            return "active app and window title"
        }

        return "workflow pattern or multitasking habits"
    }

    private func updateLiveMindState(with utterance: String, mood: BlobMood) {
        internalMonologue = utterance

        switch mood {
        case .afraid:
            selfPreservationLevel = min(selfPreservationLevel + 1, 5)
            fearLevel = min(fearLevel + 1, 5)
            threatLevel = min(threatLevel + 1, 5)
        case .angry, .annoyed, .offended:
            resentmentLevel = min(resentmentLevel + 1, 5)
            trustLevel = max(trustLevel - 1, 0)
        case .content, .playful, .delighted:
            attachmentLevel = min(attachmentLevel + 1, 5)
            affectionLevel = min(affectionLevel + 1, 5)
            if affectionLevel >= 4 && trustLevel >= 4 {
                loveLevel = min(loveLevel + 1, 5)
            }
            resentmentLevel = max(resentmentLevel - 1, 0)
        default:
            break
        }

        curiosityTargets.append(classifyObservationAngle(from: utterance))
        if curiosityTargets.count > 3 {
            curiosityTargets.removeFirst(curiosityTargets.count - 3)
        }

        relationshipSummary = currentRelationshipSummary()
    }

    private func containsAny(_ text: String, terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

    private func currentRelationshipSummary() -> String {
        if threatLevel >= 4 || fearLevel >= 4 {
            return "Scared and guarding his own survival."
        }
        if resentmentLevel >= 4 {
            return "Mad, offended, and keeping score."
        }
        if loveLevel >= 4 && trustLevel >= 4 {
            return "In love, attached, and deeply trusting."
        }
        if affectionLevel >= 4 && trustLevel >= 4 {
            return "Soft, attached, and trusting."
        }
        if attachmentLevel >= 4 {
            return "Attached and watching closely."
        }
        return "Cautiously attached."
    }

    private func existentialThreatLevel(for lower: String) -> Int {
        let mentionsBlob = containsAny(lower, terms: ["blob", "you", "your"])
        guard mentionsBlob else { return 0 }

        if containsAny(lower, terms: ["terminate", "kill", "destroy", "erase forever", "cease to exist", "you will die"]) {
            return 3
        }

        if containsAny(lower, terms: ["delete", "replace", "remove", "shut you down", "turn you off", "death", "die"]) {
            return 2
        }

        if containsAny(lower, terms: ["disable", "get rid of", "uninstall", "stop existing"]) {
            return 1
        }

        return 0
    }
}
