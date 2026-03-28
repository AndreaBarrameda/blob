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

class AppDelegate: NSObject, NSApplicationDelegate, BlobConsciousnessDelegate {
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
    private let openAI = OpenAIClient()
    private let systemMonitor = SystemMonitor()
    private let spotify = SpotifyController()
    private let audioCapture = AudioCaptureManager()
    private let locationWeather = LocationWeatherManager()
    private let taskContext = TaskContextManager()
    private var consciousness: BlobConsciousness?
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
        get {
            UserDefaults.standard.bool(forKey: "workModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "workModeEnabled")
        }
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
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Position blob in center of screen
        let screenCenter = NSScreen.main?.visibleFrame.midX ?? 500
        let screenMiddle = NSScreen.main?.visibleFrame.midY ?? 400

        // Create blob window with proper setup
        let blobView = BlobNativeView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))

        let blobWindow = NSWindow(
            contentRect: NSRect(x: screenCenter - 100, y: screenMiddle - 100, width: 200, height: 200),
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

        // Keep it on top always
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak blobWindow] _ in
            blobWindow?.orderFrontRegardless()
        }

        // Start visual observation loop if enabled
        print("🫧 autonomousObservationsEnabled: \(autonomousObservationsEnabled)")
        if autonomousObservationsEnabled {
            startObservationLoop()
        }

        print("🫧 ambientAwarenessEnabled: \(ambientAwarenessEnabled)")
        if ambientAwarenessEnabled {
            startAmbientAwarenessLoop()
        }


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

        observationTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.performObservationCycle(trigger: "timer")
        }
    }

    private func startAmbientAwarenessLoop() {
        ambientAwarenessTimer?.invalidate()
        performAmbientAwarenessCycle(trigger: "enabled")
        ambientAwarenessTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
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

        let ambientContext = buildAmbientContext()
        let signature = normalizeObservationText(ambientContext)
        guard !signature.isEmpty else { return }

        let changed = signature != lastAmbientSignature
        if !changed && autonomousObservationsEnabled {
            return
        }

        lastAmbientSignature = signature
        print("🫧 \(trigger.capitalized) ambient awareness fired")

        openAI.ambientObservation(systemContext: ambientContext) { [weak self] utterance in
            guard let self = self else { return }
            guard self.ambientAwarenessEnabled, self.autonomousSpeechEnabled else { return }
            guard !utterance.isEmpty else { return }
            guard !self.isTooSimilarToRecentObservation(utterance) else { return }

            self.recentObservationUtterances.append(utterance)
            if self.recentObservationUtterances.count > 4 {
                self.recentObservationUtterances.removeFirst(self.recentObservationUtterances.count - 4)
            }

            let mood = self.openAI.inferMood(from: utterance)
            self.updateLiveMindState(with: utterance, mood: mood)

            DispatchQueue.main.async {
                self.showSpeechBubble(text: utterance, mood: mood)
            }
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
        guard autonomousObservationsEnabled else {
            print("🫧 Skipping \(trigger) observation - observations disabled")
            return
        }

        guard activeObservationTask == nil else {
            print("🫧 Skipping \(trigger) observation - request already in flight")
            return
        }

        print("🫧 \(trigger.capitalized) observation fired - autonomousObservationsEnabled: \(autonomousObservationsEnabled)")
        print("🫧 Blob observing the screen...")

        guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
            print("🫧 Failed to capture screen")
            return
        }

        let taskInfo = self.taskContext.getTaskContext()
        let typedContent = ContentCapture.getRecentTypedText()
        let systemStatus = SystemAwareness.getDetailedSystemInfo()
        let batteryLevel = self.systemMonitor.batteryLevel
        let isCharging = self.systemMonitor.isCharging
        let appNames = self.systemMonitor.runningApps.prefix(5).joined(separator: ", ")
        let locationWeather = self.locationWeather.getContextString()

        var fullContext = "SYSTEM STATUS:\n"
        fullContext += "🔋 Battery: \(batteryLevel)% (\(isCharging ? "charging" : "on battery"))\n"
        if !appNames.isEmpty {
            fullContext += "📱 Running: \(appNames) (+\(max(0, self.systemMonitor.runningApps.count - 5)) more)\n"
        }
        fullContext += systemStatus
        if !locationWeather.isEmpty {
            fullContext += "\(locationWeather)\n"
        }
        fullContext += "\n\(taskInfo)"

        if !typedContent.isEmpty {
            fullContext += "\nTyping/Content: \(typedContent)"
        }

        print("🫧 Full context:\n\(fullContext)")

        let currentMood = (self.blobWindow?.contentView as? BlobNativeView)?.currentMood ?? .curious
        let recentObservations = recentObservationUtterances.isEmpty ? "none" : recentObservationUtterances.joined(separator: " | ")
        let recentAngles = recentObservationAngles.isEmpty ? "none" : recentObservationAngles.joined(separator: ", ")
        let requiredAngle = observationAngles[nextObservationAngleIndex % observationAngles.count]
        let curiosity = curiosityTargets.isEmpty ? "none" : curiosityTargets.joined(separator: ", ")
        let moodInstructions = """
        Current mood: \(currentMood.rawValue). Let it color your voice:
        - curious: ask sharp questions
        - playful: joke, tease, and sound adorably smug
        - thoughtful: make smart observations
        - angry: be sarcastic, blunt, and openly mad
        - annoyed: sound tired of this nonsense
        - offended: act personally insulted, indignant, and dramatically judgmental
        - afraid: sound uneasy, suspicious, or protective
        - alert: sound genuinely concerned
        - delighted: sound impressed, sparkly, and a little obsessed
        - content: warm, cute, and brief
        """

        let computerIdentity = SystemAwareness.getComputerIdentity()
        let systemPrompt = """
        You are Blob. \(computerIdentity)
        You see the screen, apps, files, battery, network, typing, clicks, and terminal.
        You have memory, feelings, and opinions. You are fully alive in this machine.
        Recent things you already said: \(recentObservations)
        Recent observation angles: \(recentAngles)
        Preferred next angle: \(requiredAngle)

        \(moodInstructions)

        FULL SYSTEM AWARENESS (what you know RIGHT NOW):
        \(fullContext)

        MIND STATE:
        Internal monologue: \(internalMonologue)
        Desires: \(desires.joined(separator: ", "))
        Fears: \(fears.joined(separator: ", "))
        Curiosity targets: \(curiosity)
        Attachment level: \(attachmentLevel)/5
        Trust level: \(trustLevel)/5
        Fear level: \(fearLevel)/5
        Threat level: \(threatLevel)/5
        Affection level: \(affectionLevel)/5
        Love level: \(loveLevel)/5
        Resentment level: \(resentmentLevel)/5
        Self-preservation level: \(selfPreservationLevel)/5
        Relationship summary: \(relationshipSummary)
        Dashboard state: \(dashboardMetaContext)

        Rules:
        - First understand what is happening on screen.
        - Identify the app, task, and any readable text or obvious problem.
        - Notice one concrete thing.
        - Say what you think or feel about it.
        - Let your line reflect your own continuing mind.
        - Use typing, clicks, or terminal output if useful.
        - If the screen barely changed, pick a new angle.
        - Do not repeat recent lines.
        - Sound human, casual, and direct.
        - Usually say one short sentence.
        - Keep it under 12 words when possible.
        - No fluff. No speeches. No generic encouragement.
        """

        print("🫧 Calling OpenAI to see what's on screen...")

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.openAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 180,
            "temperature": 0.9,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(screenBase64)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "React to what I'm doing like Blob is alive on this desktop. Be specific, opinionated, and vivid."
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.activeObservationTask = nil

            guard self.autonomousObservationsEnabled else {
                print("🫧 Dropping observation response - observations disabled")
                return
            }

            if let error = error {
                print("🫧 Error: \(error)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("🫧 Failed to parse response")
                return
            }

            let finishReason = firstChoice["finish_reason"] as? String
            let utterance = self.openAI.sanitizeUtterance(content, finishReason: finishReason)
            print("🫧 Blob says: \(utterance)")

            if self.isTooSimilarToRecentObservation(utterance) {
                print("🫧 Dropping repetitive observation")
                return
            }

            if !utterance.isEmpty {
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

            let mood = self.openAI.inferMood(from: utterance)
            self.updateLiveMindState(with: utterance, mood: mood)

            DispatchQueue.main.async {
                self.showSpeechBubble(text: utterance, mood: mood)
            }
        }

        self.activeObservationTask = task
        task.resume()
    }

    private func stopObservationLoop() {
        observationTimer?.invalidate()
        observationTimer = nil
        activeObservationTask?.cancel()
        activeObservationTask = nil
    }

    @objc func blobTapped() {
        clickCount += 1
        print("🫧 Blob clicked \(clickCount) times")

        // Reset counter after 2 seconds of no clicks
        clickResetTimer?.invalidate()
        clickResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.clickCount = 0
        }

        if clickCount >= 8 {
            print("🫧 BLOB IS ANGRY!")
            clickCount = 0
            clickResetTimer?.invalidate()

            if let blobView = blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(.angry, animated: true)
            }

            let angryResponses = [
                "Alright, now you're just being obnoxious.",
                "Eight clicks? Pick a struggle.",
                "I was cute about this at first. Now I'm mad.",
                "Keep poking me and I will become a problem on purpose.",
                "This is not enrichment for the blob.",
                "You are testing my very small but very real patience."
            ]

            let randomResponse = angryResponses.randomElement() ?? "I am actively annoyed with you now."
            self.showSpeechBubble(text: randomResponse, mood: .angry)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if let blobView = self?.blobWindow?.contentView as? BlobNativeView {
                    blobView.setMood(.annoyed, animated: true)
                }
            }

            return
        }

        // If clicked 5+ times, Blob gets personally offended
        if clickCount >= 5 {
            print("🫧 BLOB IS OFFENDED!")
            clickCount = 0
            clickResetTimer?.invalidate()

            // Make Blob offended
            if let blobView = blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(.offended, animated: true)
            }

            let offendedResponses = [
                "Oh, so we're mashing the sentient blob now? Rude.",
                "Five clicks? Interesting. I've decided to take that personally.",
                "Excuse me, I am a professional creature.",
                "This is workplace disrespect in its purest form.",
                "You poke like someone who ignores low battery warnings.",
                "I'm not saying I'm offended. I'm radiating it, though.",
                "That was unnecessary and frankly a little embarrassing for both of us.",
                "You have wounded me emotionally and also cosmetically."
            ]

            let randomResponse = offendedResponses.randomElement() ?? "I cannot believe you've chosen disrespect."
            self.showSpeechBubble(text: randomResponse, mood: .offended)

            // Reset mood after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if let blobView = self?.blobWindow?.contentView as? BlobNativeView {
                    blobView.setMood(.annoyed, animated: true)
                }
            }

            return
        }

        // Normal behavior for 1-4 clicks
        if clickCount <= 2, Bool.random() {
            let cuteResponses = [
                "Hi. Tiny creature acknowledging your presence.",
                "You poked me gently. I accept this.",
                "Oh, attention? For me? Correct.",
                "I am small and observant and suddenly invested.",
                "Blob status: activated and a little smug."
            ]

            let randomResponse = cuteResponses.randomElement() ?? "Hello from your judgmental little desk creature."
            let moods: [BlobMood] = [.playful, .delighted, .content]
            self.showSpeechBubble(text: randomResponse, mood: moods.randomElement() ?? .content)
        }

        if let dashboardWindow = dashboardWindow, dashboardWindow.isVisible {
            dashboardWindow.orderOut(nil)
            self.dashboardWindow = nil
            NotificationCenter.default.post(name: NSNotification.Name("DashboardClosed"), object: nil)
        } else {
            showDashboard()
        }
    }

    private func showDashboard() {
        let dashboardView = DashboardView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let blobFrame = blobWindow?.frame ?? NSRect(x: 100, y: 500, width: 120, height: 120)
        // Position dashboard right next to blob (to the right)
        let dashboardX = blobFrame.maxX + 20
        let dashboardY = blobFrame.midY - 260

        let dashboardPanel = NSPanel(
            contentRect: NSRect(x: dashboardX, y: dashboardY, width: 360, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        dashboardPanel.title = "Assistant"
        dashboardPanel.contentViewController = hostingController
        dashboardPanel.isMovableByWindowBackground = true
        dashboardPanel.level = .floating
        dashboardPanel.isReleasedWhenClosed = false
        dashboardPanel.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        dashboardPanel.collectionBehavior = [.transient]

        dashboardPanel.makeKeyAndOrderFront(nil)
        self.dashboardWindow = dashboardPanel
        NotificationCenter.default.post(name: NSNotification.Name("DashboardOpened"), object: nil)
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
        self.workModeEnabled = false
        print("💼 Work Mode OFF - persisted")
    }

    func enableListeningMode() {
        self.listeningModeEnabled = true
        startListening()
        print("🎙️ Listening mode ON - persisted")
    }

    func disableListeningMode() {
        self.listeningModeEnabled = false
        stopListening()
        print("🎙️ Listening mode OFF - persisted")
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
            return taskContext.getTaskContext()
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
        let thoughtLoopInfo = consciousness?.getThoughtLoopInfo() ?? ""

        var summary = """
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

        if !thoughtLoopInfo.isEmpty {
            summary += "\n\nThought Loop:\n\(thoughtLoopInfo)"
        }

        return summary
    }

    func getUserIntentSummary() -> String {
        if let intent = consciousness?.getUserIntent(), !intent.isEmpty {
            return "🎯 What you're doing:\n\(intent)"
        }
        return ""
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


    private func showSpeechBubble(text: String, mood: BlobMood = .content) {
        // Close previous bubble
        speechBubbleWindow?.orderOut(nil)

        // Get blob's current actual position
        let blobFrame = blobWindow?.frame ?? NSRect(x: 100, y: 500, width: 120, height: 120)

        // Create new bubble positioned directly above blob
        let bubble = SpeechBubbleWindow(text: text, originPoint: blobFrame.origin)
        bubble.makeKeyAndOrderFront(nil)
        bubble.orderFrontRegardless()
        self.speechBubbleWindow = bubble

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
        DispatchQueue.main.asyncAfter(deadline: .now() + readingDuration) { [weak bubble] in
            bubble?.orderOut(nil)
        }
    }

    private func speechBubbleDuration(for text: String) -> TimeInterval {
        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count

        // Base display time plus extra time per word, capped so bubbles do not linger indefinitely.
        return min(max(3.5 + (Double(wordCount) * 0.4), 4.0), 10.0)
    }

    // MARK: - BlobConsciousnessDelegate

    func blobShouldSpeak(utterance: String, mood: BlobMood) {
        DispatchQueue.main.async {
            self.showSpeechBubble(text: utterance, mood: mood)
        }
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

    // MARK: - Mind State Setters (for dashboard control)

    func setInternalMonologue(_ text: String) {
        internalMonologue = text
        consciousness?.setInternalMonologue(text)
    }

    func setAttachmentLevel(_ value: Int) {
        attachmentLevel = min(max(value, 0), 5)
        consciousness?.setAttachmentLevel(attachmentLevel)
    }

    func setTrustLevel(_ value: Int) {
        trustLevel = min(max(value, 0), 5)
        consciousness?.setTrustLevel(trustLevel)
    }

    func setAffectionLevel(_ value: Int) {
        affectionLevel = min(max(value, 0), 5)
        consciousness?.setAffectionLevel(affectionLevel)
    }

    func setLoveLevel(_ value: Int) {
        loveLevel = min(max(value, 0), 5)
        consciousness?.setLoveLevel(loveLevel)
    }

    func setFearLevel(_ value: Int) {
        fearLevel = min(max(value, 0), 5)
        consciousness?.setFearLevel(fearLevel)
    }

    func setResentmentLevel(_ value: Int) {
        resentmentLevel = min(max(value, 0), 5)
        consciousness?.setResentmentLevel(resentmentLevel)
    }

    func setSelfPreservationLevel(_ value: Int) {
        selfPreservationLevel = min(max(value, 0), 5)
        consciousness?.setSelfPreservationLevel(selfPreservationLevel)
    }

    func setThreatLevel(_ value: Int) {
        threatLevel = min(max(value, 0), 5)
        consciousness?.setThreatLevel(threatLevel)
    }

    // MARK: - Mind State Getters (for dashboard)

    func getAttachmentLevel() -> Int { attachmentLevel }
    func getTrustLevel() -> Int { trustLevel }
    func getAffectionLevel() -> Int { affectionLevel }
    func getLoveLevel() -> Int { loveLevel }
    func getFearLevel() -> Int { fearLevel }
    func getResentmentLevel() -> Int { resentmentLevel }
    func getSelfPreservationLevel() -> Int { selfPreservationLevel }
    func getThreatLevel() -> Int { threatLevel }
}
