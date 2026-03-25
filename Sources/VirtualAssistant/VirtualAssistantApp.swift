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
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 8...15), repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Generate random thoughts based on system state
            let prompts = [
                "Say something fun and short (max 8 words) about your day",
                "Make a brief witty comment (max 8 words) about something you observe",
                "Say a short philosophical thought (max 8 words)",
                "Tell a very short joke (max 8 words)",
                "Say something encouraging (max 8 words)",
                "Share a random fact briefly (max 8 words)"
            ]

            let randomPrompt = prompts.randomElement() ?? "Say something!"
            let batteryInfo = "The user's battery is at \(self.systemMonitor.batteryLevel)%."
            let appsInfo = "They have \(self.systemMonitor.runningApps.count) apps open."

            let fullPrompt = "\(randomPrompt) \(batteryInfo) \(appsInfo) Keep it adorable and brief!"

            self.openAI.chat(message: fullPrompt) { [weak self] response in
                DispatchQueue.main.async {
                    self?.showSpeechBubble(text: response, nearPoint: blobWindowFrame.origin)
                }
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
