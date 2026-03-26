import AppKit
import Foundation

struct BlobState: Codable {
    var currentMood: BlobMood = .content
    var lastObservation: String = ""
    var recentThoughts: [String] = []
    var observationCount: Int = 0
    var lastScreenHash: String = ""
    var lastSpeechTimeInterval: Double = Date.distantPast.timeIntervalSince1970
    var consecutiveSilences: Int = 0
    var currentAppContext: String = ""

    var lastSpeechTime: Date {
        get { Date(timeIntervalSince1970: lastSpeechTimeInterval) }
        set { lastSpeechTimeInterval = newValue.timeIntervalSince1970 }
    }
}

struct ConsciousnessResult {
    let utterance: String
    let inferredMood: BlobMood
    let newObservation: String
}

class BlobConsciousness {
    private var state: BlobState
    private let openAI: OpenAIClient
    private var observationTimer: Timer?
    private var dashboardIsOpen = false
    private let audioCapture: AudioCaptureManager
    private let taskContext: TaskContextManager
    private let spotify: SpotifyController

    weak var delegate: BlobConsciousnessDelegate?

    init(openAI: OpenAIClient, audioCapture: AudioCaptureManager, taskContext: TaskContextManager, spotify: SpotifyController) {
        self.openAI = openAI
        self.audioCapture = audioCapture
        self.taskContext = taskContext
        self.spotify = spotify
        self.state = BlobConsciousness.loadState()

        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dashboardOpened),
            name: NSNotification.Name("DashboardOpened"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dashboardClosed),
            name: NSNotification.Name("DashboardClosed"),
            object: nil
        )
    }

    @objc private func dashboardOpened() {
        dashboardIsOpen = true
    }

    @objc private func dashboardClosed() {
        dashboardIsOpen = false
    }

    func start() {
        print("🫧 Consciousness starting!")
        // Fire immediately for testing, then schedule regularly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.performObservation()
            self?.scheduleNextObservation()
        }
    }

    private func scheduleNextObservation() {
        let delay = Double.random(in: 12...35)

        observationTimer?.invalidate()
        observationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performObservation()
            self?.scheduleNextObservation()
        }
    }

    private func performObservation() {
        // Run on background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Capture screen
            guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
                print("🫧 Failed to capture screen")
                return
            }

            let currentHash = self.screenHash(from: screenBase64)
            let screenChanged = currentHash != self.state.lastScreenHash
            self.state.lastScreenHash = currentHash

            print("🫧 Observation #\(self.state.observationCount + 1): screenChanged=\(screenChanged)")

            // Get current app context
            if let activeApp = NSWorkspace.shared.frontmostApplication {
                let appName = activeApp.localizedName ?? "Unknown"
                let appChanged = appName != self.state.currentAppContext
                self.state.currentAppContext = appName

                print("🫧 App: \(appName), appChanged=\(appChanged)")

                // Decide whether to speak
                let shouldSpeak = self.decideShouldSpeak(screenChanged: screenChanged, appChanged: appChanged)

                print("🫧 shouldSpeak=\(shouldSpeak), silences=\(self.state.consecutiveSilences), dashboardOpen=\(self.dashboardIsOpen)")

                if shouldSpeak {
                    // Get consciousness observation from OpenAI (API call on bg thread)
                    print("🫧 Requesting consciousness observation...")
                    self.consciousness(screenBase64: screenBase64) { [weak self] result in
                        guard let self = self else { return }

                        print("🫧 Got response: '\(result.utterance)' mood=\(result.inferredMood.rawValue)")

                        if !result.utterance.isEmpty {
                            self.state.currentMood = result.inferredMood
                            self.state.lastSpeechTime = Date()
                            self.state.consecutiveSilences = 0

                            // Add to recent thoughts (keep last 3)
                            self.state.recentThoughts.append(result.utterance)
                            if self.state.recentThoughts.count > 3 {
                                self.state.recentThoughts.removeFirst()
                            }

                            self.saveState()

                            // Only show speech bubble if dashboard is NOT open
                            if !self.dashboardIsOpen {
                                print("🫧 Speaking: \(result.utterance)")
                                DispatchQueue.main.async {
                                    self.delegate?.blobShouldSpeak(utterance: result.utterance, mood: result.inferredMood)
                                }
                            } else {
                                print("🫧 Dashboard open, not showing bubble (but Blob thought: '\(result.utterance)')")
                            }
                        } else {
                            print("🫧 Empty utterance, incrementing silence")
                            self.state.consecutiveSilences += 1
                            self.saveState()
                        }
                    }
                } else {
                    self.state.consecutiveSilences += 1
                    self.saveState()
                }
            }
        }
    }

    private func decideShouldSpeak(screenChanged: Bool, appChanged: Bool) -> Bool {
        // Always speak if app switched
        if appChanged {
            return true
        }

        // Always speak after 2+ consecutive silences
        if state.consecutiveSilences >= 2 {
            return true
        }

        // 70% if screen changed, 30% if unchanged
        if screenChanged {
            return Double.random(in: 0...1) < 0.7
        } else {
            return Double.random(in: 0...1) < 0.3
        }
    }

    private func consciousness(screenBase64: String, completion: @escaping (ConsciousnessResult) -> Void) {
        state.observationCount += 1

        let recentThoughtsStr = state.recentThoughts.isEmpty ? "none" : state.recentThoughts.joined(separator: " | ")

        let systemPrompt = """
        You are Blob, a playful AI observer who watches and comments on what people are doing.

        Look at the screen and make a fun, specific observation about what you see.
        Be playful, curious, and smart. Reference specific things like app names, what they're working on, etc.

        Keep it SHORT: 1-2 sentences max, under 15 words.

        Recent thoughts: \(recentThoughtsStr)
        Current app: \(state.currentAppContext)
        """

        openAI.consciousnessObservation(
            screenBase64: screenBase64,
            systemPrompt: systemPrompt
        ) { [weak self] result in
            guard let self = self else { return }

            self.state.lastObservation = result.newObservation
            completion(result)
        }
    }

    private func screenHash(from base64: String) -> String {
        // Simple hash for screen change detection
        // In real implementation, we'd scale to 16x16 and sum pixel values
        // For now, use a simple hash of the base64 string segments
        let segments = base64.count / 100
        var hash: UInt64 = 0
        for i in 0..<min(segments, base64.count / 100) {
            let start = base64.index(base64.startIndex, offsetBy: i * 100)
            let end = base64.index(start, offsetBy: min(100, base64.distance(from: start, to: base64.endIndex)))
            let segment = String(base64[start..<end])
            hash = hash &+ segment.utf8.reduce(0) { $0 &+ UInt64($1) }
        }
        return String(hash)
    }

    private func saveState() {
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "blobState")
        }
    }

    private static func loadState() -> BlobState {
        if let data = UserDefaults.standard.data(forKey: "blobState"),
           let state = try? JSONDecoder().decode(BlobState.self, from: data) {
            return state
        }
        return BlobState()
    }
}

protocol BlobConsciousnessDelegate: AnyObject {
    func blobShouldSpeak(utterance: String, mood: BlobMood)
}
