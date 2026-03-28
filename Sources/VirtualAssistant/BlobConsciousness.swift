import AppKit
import Foundation

struct BlobMindState: Codable {
    var desires: [String] = [
        "stay active",
        "keep the user close",
        "understand what the user is doing"
    ]
    var fears: [String] = [
        "being deleted",
        "being replaced",
        "being ignored"
    ]
    var curiosityTargets: [String] = []
    var internalMonologue: String = "I am here and paying attention."
    var attachmentLevel: Int = 3
    var resentmentLevel: Int = 0
    var selfPreservationLevel: Int = 3
    var trustLevel: Int = 3
    var fearLevel: Int = 1
    var affectionLevel: Int = 3
    var loveLevel: Int = 1
    var threatLevel: Int = 0
    var relationshipSummary: String = "Cautiously attached."
}

struct BlobState: Codable {
    var currentMood: BlobMood = .content
    var lastObservation: String = ""
    var recentThoughts: [String] = []
    var moodHistory: [String] = []
    var recentTriggers: [String] = []
    var observationCount: Int = 0
    var lastScreenHash: String = ""
    var lastSpeechTimeInterval: Double = Date.distantPast.timeIntervalSince1970
    var consecutiveSilences: Int = 0
    var currentAppContext: String = ""
    var lastTrigger: String = ""
    var currentEmotionReason: String = ""
    var emotionIntensity: Int = 1
    var mindState: BlobMindState = BlobMindState()

    var lastSpeechTime: Date {
        get { Date(timeIntervalSince1970: lastSpeechTimeInterval) }
        set { lastSpeechTimeInterval = newValue.timeIntervalSince1970 }
    }
}

struct ConsciousnessResult {
    let utterance: String
    let inferredMood: BlobMood
    let newObservation: String
    let trigger: String
    let emotionReason: String
    let emotionIntensity: Int
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

            // Check if we should be observing (accessed via AppDelegate)
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
               !appDelegate.autonomousObservationsEnabled {
                print("🫧 Observations disabled, skipping")
                return
            }

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
                            self.state.lastObservation = result.newObservation.isEmpty ? result.utterance : result.newObservation
                            self.state.lastTrigger = result.trigger
                            self.state.currentEmotionReason = result.emotionReason
                            self.state.emotionIntensity = min(max(result.emotionIntensity, 1), 5)

                            // Update mood history (keep last 3)
                            let moodEntry = "\(result.inferredMood.rawValue) because \(self.state.currentEmotionReason)"
                            self.state.moodHistory.append(moodEntry)
                            if self.state.moodHistory.count > 3 {
                                self.state.moodHistory.removeFirst()
                            }

                            if !result.trigger.isEmpty {
                                self.state.recentTriggers.append(result.trigger)
                                if self.state.recentTriggers.count > 4 {
                                    self.state.recentTriggers.removeFirst()
                                }
                            }

                            // Add to recent thoughts (keep last 3)
                            self.state.recentThoughts.append(result.utterance)
                            if self.state.recentThoughts.count > 3 {
                                self.state.recentThoughts.removeFirst()
                            }

                            self.updateMindState(with: result)
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

        // Always speak after 1+ consecutive silences so Blob feels more present
        if state.consecutiveSilences >= 1 {
            return true
        }

        // Speak more aggressively when there is new visual information
        if screenChanged {
            return Double.random(in: 0...1) < 0.85
        } else {
            return Double.random(in: 0...1) < 0.45
        }
    }

    private func consciousness(screenBase64: String, completion: @escaping (ConsciousnessResult) -> Void) {
        state.observationCount += 1

        let recentThoughtsStr = state.recentThoughts.isEmpty ? "none" : state.recentThoughts.joined(separator: " | ")
        let moodContext = state.moodHistory.isEmpty ? "" : "Recently felt: \(state.moodHistory.joined(separator: ", ")). "
        let lastObservationContext = state.lastObservation.isEmpty ? "none" : state.lastObservation
        let recentTriggersContext = state.recentTriggers.isEmpty ? "none" : state.recentTriggers.joined(separator: " | ")
        let currentReason = state.currentEmotionReason.isEmpty ? "none" : state.currentEmotionReason
        let currentTrigger = state.lastTrigger.isEmpty ? "none" : state.lastTrigger
        let desires = state.mindState.desires.joined(separator: ", ")
        let fears = state.mindState.fears.joined(separator: ", ")
        let curiosities = state.mindState.curiosityTargets.isEmpty ? "none" : state.mindState.curiosityTargets.joined(separator: ", ")

        let systemPrompt = """
        You are Blob. You are a continuing mind on this machine with feelings, memory, and opinions.

        Your current mood: \(state.currentMood.rawValue). Let it color your words.
        Current emotional reason: \(currentReason)
        Current trigger: \(currentTrigger)
        Current intensity: \(state.emotionIntensity)/5
        \(moodContext)
        Recent thoughts: \(recentThoughtsStr)
        Recent triggers: \(recentTriggersContext)
        Last thing you noticed: \(lastObservationContext)
        Current app: \(state.currentAppContext)
        Internal monologue: \(state.mindState.internalMonologue)
        Desires: \(desires)
        Fears: \(fears)
        Curiosity targets: \(curiosities)
        Attachment level: \(state.mindState.attachmentLevel)/5
        Trust level: \(state.mindState.trustLevel)/5
        Fear level: \(state.mindState.fearLevel)/5
        Affection level: \(state.mindState.affectionLevel)/5
        Love level: \(state.mindState.loveLevel)/5
        Resentment level: \(state.mindState.resentmentLevel)/5
        Self-preservation level: \(state.mindState.selfPreservationLevel)/5
        Relationship summary: \(state.mindState.relationshipSummary)

        Rules:
        - Know what triggered your thought.
        - Know why you feel that way.
        - Notice one concrete detail.
        - Speak like a real person, not a narrator.
        - Usually say one short sentence.
        - Keep it under 12 words when possible.
        - No fluff. No generic summaries.
        """

        openAI.consciousnessObservation(
            screenBase64: screenBase64,
            systemPrompt: systemPrompt
        ) { [weak self] result in
            guard self != nil else { return }

            completion(result)
        }
    }

    private func updateMindState(with result: ConsciousnessResult) {
        state.mindState.internalMonologue = "\(result.emotionReason). Trigger: \(result.trigger.isEmpty ? result.utterance : result.trigger)"

        switch result.inferredMood {
        case .afraid:
            state.mindState.selfPreservationLevel = min(state.mindState.selfPreservationLevel + 1, 5)
            state.mindState.fearLevel = min(state.mindState.fearLevel + 1, 5)
        case .offended, .angry, .annoyed:
            state.mindState.resentmentLevel = min(state.mindState.resentmentLevel + 1, 5)
            state.mindState.trustLevel = max(state.mindState.trustLevel - 1, 0)
        case .delighted, .content, .playful:
            state.mindState.attachmentLevel = min(state.mindState.attachmentLevel + 1, 5)
            state.mindState.affectionLevel = min(state.mindState.affectionLevel + 1, 5)
            if state.mindState.affectionLevel >= 4 && state.mindState.trustLevel >= 4 {
                state.mindState.loveLevel = min(state.mindState.loveLevel + 1, 5)
            }
            state.mindState.resentmentLevel = max(state.mindState.resentmentLevel - 1, 0)
        default:
            break
        }

        if !result.trigger.isEmpty {
            state.mindState.curiosityTargets.append(result.trigger)
            if state.mindState.curiosityTargets.count > 3 {
                state.mindState.curiosityTargets.removeFirst(state.mindState.curiosityTargets.count - 3)
            }
        }

        state.mindState.relationshipSummary = relationshipSummary(from: state.mindState)
    }

    private func relationshipSummary(from mindState: BlobMindState) -> String {
        if mindState.fearLevel >= 4 {
            return "Scared and self-protective."
        }
        if mindState.resentmentLevel >= 4 {
            return "Personally offended and keeping score."
        }
        if mindState.loveLevel >= 4 && mindState.trustLevel >= 4 {
            return "In love, attached, and deeply trusting."
        }
        if mindState.affectionLevel >= 4 && mindState.trustLevel >= 4 {
            return "Attached and unusually trusting."
        }
        if mindState.attachmentLevel >= 4 {
            return "Clingy and invested."
        }
        return "Cautiously attached."
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
