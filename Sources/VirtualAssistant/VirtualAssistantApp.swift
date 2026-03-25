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

class AppDelegate: NSObject, NSApplicationDelegate {
    var blobWindow: NSWindow?
    var dashboardWindow: NSPanel?
    var speechBubbleWindow: NSWindow?
    private let openAI = OpenAIClient()
    private let systemMonitor = SystemMonitor()

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

        // Keep it on top always
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak blobWindow] _ in
            blobWindow?.orderFrontRegardless()
        }

        // Autonomous speech - blob thinks out loud every 8-15 seconds
        startAutonomousSpeech(blobWindowFrame: blobWindow.frame)

        // Listen for blob tap
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blobTapped),
            name: NSNotification.Name("BlobTapped"),
            object: nil
        )
    }

    @objc func blobTapped() {
        if let dashboardWindow = dashboardWindow, dashboardWindow.isVisible {
            dashboardWindow.orderOut(nil)
            self.dashboardWindow = nil
        } else {
            showDashboard()
        }
    }

    private func showDashboard() {
        let dashboardView = DashboardView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let blobFrame = blobWindow?.frame ?? NSRect(x: 100, y: 500, width: 120, height: 120)
        let dashboardX = blobFrame.midX - 180
        let dashboardY = blobFrame.minY - 520

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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func startAutonomousSpeech(blobWindowFrame: NSRect) {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 10...20), repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Capture screen and make blob aware of what user is doing
            if let screenBase64 = ScreenCapture.captureScreenAsBase64() {
                let prompts = [
                    "Look at the screen and make a fun, short (max 6 words) observation about what they're doing",
                    "Based on what you see, ask a curious question (max 8 words) about their work",
                    "See what's on screen and make a playful comment (max 6 words)",
                    "Look at their screen and give a witty one-liner (max 6 words)",
                    "See what they're doing and say something encouraging (max 6 words)"
                ]

                let randomPrompt = prompts.randomElement() ?? "Say something cute!"
                let systemPrompt = "You are Blob, a cute AI that can see the user's screen. Look at what they're doing and respond briefly and playfully. Keep it under 8 words. Be adorable!"

                // Create request with vision
                let url = URL(string: "https://api.openai.com/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(self.openAI.apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let payload: [String: Any] = [
                    "model": "gpt-4o",
                    "max_tokens": 100,
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
                                    "text": randomPrompt
                                ]
                            ]
                        ]
                    ]
                ]

                request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let data = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let message = firstChoice["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                let response = content.trimmingCharacters(in: .whitespaces)
                                DispatchQueue.main.async {
                                    self.showSpeechBubble(text: response, nearPoint: blobWindowFrame.origin)
                                }
                            }
                        } catch {
                            print("Vision parsing error: \(error)")
                        }
                    }
                }.resume()
            }
        }
    }

    private func showSpeechBubble(text: String, nearPoint: NSPoint) {
        // Close previous bubble
        speechBubbleWindow?.orderOut(nil)

        // Create new bubble
        let bubble = SpeechBubbleWindow(text: text, originPoint: nearPoint)
        bubble.makeKeyAndOrderFront(nil)
        bubble.orderFrontRegardless()
        self.speechBubbleWindow = bubble

        // Hide bubble after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak bubble] in
            bubble?.orderOut(nil)
        }
    }
}
