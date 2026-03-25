import Foundation

struct Memory: Codable {
    let fact: String
    let timestamp: Date
    let category: String  // "preference", "fact", "interest", etc.
}

class BlobMemory {
    private let memoryFile = "/Users/andreabarrameda/VirtualAssistant/.blob_memory.json"
    private var memories: [Memory] = []

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
