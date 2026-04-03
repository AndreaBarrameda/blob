import Foundation

struct ActivityState: Codable, Equatable {
    var observedAt: Date = Date()
    var frontmostApp: String = ""
    var windowTitle: String = ""
    var fileType: String = ""
    var currentTask: String = ""
    var projectContext: String = ""
    var terminalContext: String = ""
    var typedSnippet: String = ""
    var browserContext: String = ""
    var currentGoal: String = ""
    var focusSummary: String = ""
    var inferredProject: String = ""
    var confidence: Double = 0.2
    var evidence: [String] = []

    func compactSummary() -> String {
        [
            frontmostApp.isEmpty ? nil : "App: \(frontmostApp)",
            focusSummary.isEmpty ? nil : "Focus: \(focusSummary)",
            currentGoal.isEmpty ? nil : "Goal: \(currentGoal)",
            browserContext.isEmpty ? nil : "Browser: \(browserContext)",
            terminalContext.isEmpty ? nil : "Terminal: \(terminalContext)",
            typedSnippet.isEmpty ? nil : "Typing: \(typedSnippet)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    func primaryLabel() -> String {
        if !focusSummary.isEmpty { return focusSummary }
        if !currentTask.isEmpty { return currentTask }
        if !windowTitle.isEmpty { return windowTitle }
        if !frontmostApp.isEmpty { return frontmostApp }
        return "waiting"
    }
}

struct BlobPresenceState: Codable {
    var currentFocus: String = "waiting"
    var focusConfidence: Double = 0.2
    var currentProject: String = ""
    var currentGoal: String = ""
    var lastKnownApp: String = ""
    var internalMonologue: String = "I am here and paying attention."
    var stableMood: BlobMood = .content
    var energy: Double = 0.72
    var attentiveness: Double = 0.55
    var socialNeed: Double = 0.35
    var lastObservedChangeAt: Date = Date()
    var lastInteractionAt: Date = Date()
    var lastSpokeAt: Date?
    var recentTransitions: [String] = []

    mutating func pushTransition(_ value: String) {
        guard !value.isEmpty else { return }
        recentTransitions.append(value)
        if recentTransitions.count > 6 {
            recentTransitions.removeFirst(recentTransitions.count - 6)
        }
    }

    func summary() -> String {
        let transitions = recentTransitions.isEmpty ? "none" : recentTransitions.joined(separator: " | ")
        return """
        Blob Presence:
        Focus: \(currentFocus)
        Focus confidence: \(Int(focusConfidence * 100))%
        Project: \(currentProject.isEmpty ? "unknown" : currentProject)
        Goal: \(currentGoal.isEmpty ? "none" : currentGoal)
        Last app: \(lastKnownApp.isEmpty ? "unknown" : lastKnownApp)
        Energy: \(Int(energy * 100))%
        Attention: \(Int(attentiveness * 100))%
        Social need: \(Int(socialNeed * 100))%
        Internal monologue: \(internalMonologue)
        Recent transitions: \(transitions)
        """
    }
}

final class BlobPresenceStore {
    let filePath: String

    init() {
        let projectRoot: String
        if let execURL = Bundle.main.executableURL {
            projectRoot = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
        } else {
            projectRoot = FileManager.default.currentDirectoryPath
        }
        filePath = projectRoot + "/BLOB_STATE.json"
    }

    func load() -> BlobPresenceState {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return BlobPresenceState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(BlobPresenceState.self, from: data)) ?? BlobPresenceState()
    }

    func save(_ state: BlobPresenceState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }
}
