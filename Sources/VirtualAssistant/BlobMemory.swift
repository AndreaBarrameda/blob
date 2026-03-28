import Foundation
import Combine

struct Memory: Codable {
    let id: UUID
    let fact: String
    let timestamp: Date
    let category: String  // "preference", "fact", "interest", "short_term", "long_term", "emotional"

    enum CodingKeys: String, CodingKey {
        case id, fact, timestamp, category
    }

    init(fact: String, timestamp: Date, category: String, id: UUID = UUID()) {
        self.id = id
        self.fact = fact
        self.timestamp = timestamp
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id with backwards compatibility
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID()
        }

        fact = try container.decode(String.self, forKey: .fact)
        category = try container.decode(String.self, forKey: .category)

        // Handle both string and double timestamps
        if let doubleTime = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: doubleTime)
        } else if let stringTime = try? container.decode(String.self, forKey: .timestamp),
                  let doubleTime = Double(stringTime) {
            timestamp = Date(timeIntervalSince1970: doubleTime)
        } else {
            timestamp = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fact, forKey: .fact)
        try container.encode(category, forKey: .category)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .timestamp)
    }
}

class BlobMemory: ObservableObject {
    @Published var memories: [Memory] = []
    private let memoryFile = "/Users/andreabarrameda/VirtualAssistant/.blob_memory.json"

    init() {
        loadMemories()
    }

    private func loadMemories() {
        if FileManager.default.fileExists(atPath: memoryFile) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: memoryFile))
                memories = try JSONDecoder().decode([Memory].self, from: data)
            } catch {
                print("⚠️ Failed to load memories: \(error)")
                memories = []
            }
        }
    }

    private func saveMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: URL(fileURLWithPath: memoryFile))
        } catch {
            print("⚠️ Failed to save memories: \(error)")
        }
    }

    func addMemory(_ fact: String, category: String = "fact") {
        let memory = Memory(fact: fact, timestamp: Date(), category: category)
        memories.append(memory)
        saveMemories()
    }

    func getMemorySummary() -> String {
        guard !memories.isEmpty else {
            return "I don't have any memories yet."
        }

        let recentMemories = memories.suffix(10)  // Last 10 memories
        let facts = recentMemories
            .filter { $0.category == "fact" }
            .map { $0.fact }

        let preferences = recentMemories
            .filter { $0.category == "preference" }
            .map { $0.fact }

        var summary = ""
        if !facts.isEmpty {
            summary += "I know: \(facts.joined(separator: ", ")). "
        }
        if !preferences.isEmpty {
            summary += "User preferences: \(preferences.joined(separator: ", ")). "
        }

        return summary
    }

    func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        saveMemories()
    }

    func getMemoriesByCategory(_ category: String) -> [Memory] {
        return memories.filter { $0.category == category }
    }

    func pruneExpiredMemories() {
        let twentyFourHoursAgo = Date().addingTimeInterval(-86400)
        let beforePrune = memories.count
        memories.removeAll { memory in
            memory.category == "short_term" && memory.timestamp < twentyFourHoursAgo
        }
        if memories.count < beforePrune {
            print("🧠 Pruned \(beforePrune - memories.count) expired short-term memories")
            saveMemories()
        }
    }

    func extractMemories(from conversation: String, usingOpenAI openAI: OpenAIClient, completion: @escaping () -> Void) {
        // Use AI to extract important facts from conversation
        let prompt = """
        From this conversation, extract 1-2 important facts or preferences to remember about the user.
        Format as: "User likes X" or "User is working on Y" - keep it short.
        Conversation: \(conversation)
        """

        openAI.chat(message: prompt) { [weak self] response in
            if response.count > 5 {
                self?.addMemory(response, category: "fact")
            }
            completion()
        }
    }
}
