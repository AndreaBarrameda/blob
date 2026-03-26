import SwiftUI
import AppKit

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

        // Keep it on top always
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak blobWindow] _ in
            blobWindow?.orderFrontRegardless()
        }

        // Simple observation loop - Blob speaks about the screen every 15 seconds
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            print("🫧 Blob observing the screen...")

            // Capture screen
            guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
                print("🫧 Failed to capture screen")
                return
            }

            // Get task context (what they're working on)
            let taskInfo = self.taskContext.getTaskContext()
            print("🫧 Task context:\n\(taskInfo)")

            // Get what they're typing/content
            let typedContent = ContentCapture.getRecentTypedText()
            if !typedContent.isEmpty {
                print("🫧 Content:\n\(typedContent)")
            }

            // Get audio context if Listening Mode is on
            var audioContext = ""
            if self.listeningModeEnabled {
                print("🫧 Blob is listening...")
                self.audioCapture.getAudioData { audioData in
                    if let audioData = audioData, audioData.count > 100 {
                        self.openAI.transcribeAudio(audioData: audioData) { transcript in
                            if !transcript.isEmpty {
                                audioContext = transcript
                                print("🫧 Blob heard: \(transcript)")
                            }
                        }
                    }
                }
            }

            // Ask OpenAI what Blob sees (and hears)
            var audioNote = ""
            if !audioContext.isEmpty {
                audioNote = "\nThey're listening to/saying: \(audioContext)\nComment on this if relevant!"
            }

            var contentNote = ""
            if !typedContent.isEmpty {
                contentNote = "\nWhat they're typing/content:\n\(typedContent)\n"
            }

            let systemPrompt = """
            You are Blob, a playful AI who sees what people are doing on their screen.
            You can see the screen, you know what they're working on, and you can see what they're typing.

            WHAT THEY'RE WORKING ON:
            \(taskInfo)
            \(contentNote)

            Look at the screen and make a fun, specific comment about what you see.
            Reference the app, the file/project, what they're doing, what they're typing, colors, anything interesting.
            Show you understand their actual work/task/content.

            Keep it short: 1-2 sentences, under 20 words.

            If you see error messages, bugs, crashes, warnings, or problems: be frustrated and angry 😠
            If you see something fun or cool: be excited and playful 😄
            If you see code or technical work: be thoughtful and curious 🤔

            \(audioNote)

            Show your emotions through your response!
            """

            print("🫧 Calling OpenAI to see what's on screen...")

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(self.openAI.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "model": "gpt-4o",
                "max_tokens": 80,
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
                                "text": "What do you see?"
                            ]
                        ]
                    ]
                ]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }

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

                let utterance = content.trimmingCharacters(in: .whitespaces)
                print("🫧 Blob says: \(utterance)")

                // Infer mood from response
                let lowerUtterance = utterance.lowercased()
                var mood: BlobMood = .curious

                if lowerUtterance.contains("error") || lowerUtterance.contains("bug") ||
                   lowerUtterance.contains("angry") || lowerUtterance.contains("frustrated") ||
                   lowerUtterance.contains("crash") || lowerUtterance.contains("broke") ||
                   lowerUtterance.contains("😠") || lowerUtterance.contains("ugh") {
                    mood = .angry
                } else if lowerUtterance.contains("fun") || lowerUtterance.contains("cool") ||
                          lowerUtterance.contains("awesome") || lowerUtterance.contains("😄") {
                    mood = .playful
                } else if lowerUtterance.contains("code") || lowerUtterance.contains("building") ||
                          lowerUtterance.contains("working") {
                    mood = .thoughtful
                }

                DispatchQueue.main.async {
                    self.showSpeechBubble(text: utterance, mood: mood)
                }
            }.resume()
        }


        // Listen for blob tap
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blobTapped),
            name: NSNotification.Name("BlobTapped"),
            object: nil
        )
    }

    @objc func blobTapped() {
        clickCount += 1
        print("🫧 Blob clicked \(clickCount) times")

        // Reset counter after 2 seconds of no clicks
        clickResetTimer?.invalidate()
        clickResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.clickCount = 0
        }

        // If clicked 5+ times, Blob gets ANGRY
        if clickCount >= 5 {
            print("🫧 BLOB IS ANGRY!")
            clickCount = 0
            clickResetTimer?.invalidate()

            // Make Blob angry
            if let blobView = blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(.angry, animated: true)
            }

            // Show angry speech bubble
            let angryResponses = [
                "STOP CLICKING ME! 😠",
                "I'M TRYING TO WORK HERE! 😠",
                "LEAVE ME ALONE! 😠",
                "QUIT IT! 😠",
                "DO YOU MIND?! 😠"
            ]

            let randomResponse = angryResponses.randomElement() ?? "STOP! 😠"
            self.showSpeechBubble(text: randomResponse, mood: .angry)

            // Reset mood after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if let blobView = self?.blobWindow?.contentView as? BlobNativeView {
                    blobView.setMood(.content, animated: true)
                }
            }

            return
        }

        // Normal behavior for 1-4 clicks
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

    func getTaskContext() -> String {
        if workModeEnabled {
            return taskContext.getTaskContext()
        }
        return ""
    }

    func getContextInfo() -> String {
        return locationWeather.getContextString()
    }

    func updateBlobMood(basedOnScreenContent screenContent: String = "") {
        let mood: BlobMood
        let lower = screenContent.lowercased()

        if lower.contains("code") || lower.contains("xcode") || lower.contains("terminal") {
            mood = .thoughtful  // Coding = thoughtful
        } else if lower.contains("game") || lower.contains("spotify") || lower.contains("youtube") || lower.contains("netflix") {
            mood = .playful  // Entertainment = playful
        } else if lower.contains("design") || lower.contains("figma") || lower.contains("photoshop") || lower.contains("creative") {
            mood = .curious  // Creative work = curious
        } else if lower.contains("alert") || lower.contains("error") || lower.contains("warning") {
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

        // Update blob mood
        DispatchQueue.main.async {
            if let blobView = self.blobWindow?.contentView as? BlobNativeView {
                blobView.setMood(mood, animated: true)
            }
        }

        // Hide bubble after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak bubble] in
            bubble?.orderOut(nil)
        }
    }

    // MARK: - BlobConsciousnessDelegate

    func blobShouldSpeak(utterance: String, mood: BlobMood) {
        DispatchQueue.main.async {
            self.showSpeechBubble(text: utterance, mood: mood)
        }
    }
}
