import Foundation
import Combine

class BlobMemory: ObservableObject {
    @Published var entries: [String] = []
    let memoryFile: String

    init() {
        // MEMORY.md lives next to the executable's project root
        let projectRoot: String
        if let execURL = Bundle.main.executableURL {
            // .build/debug/VirtualAssistant -> go up 3 levels to project root
            projectRoot = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
        } else {
            projectRoot = FileManager.default.currentDirectoryPath
        }
        self.memoryFile = projectRoot + "/MEMORY.md"
        loadEntries()
    }

    // Create the file with a header if it doesn't exist
    func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: memoryFile) else { return }
        let header = """
        # Blob Memory

        Everything Blob knows about the user. Newest entries at the top.

        ---

        """
        try? header.write(toFile: memoryFile, atomically: true, encoding: .utf8)
        print("🧠 Created MEMORY.md at \(memoryFile)")
    }

    private func loadEntries() {
        ensureFileExists()
        guard let content = try? String(contentsOfFile: memoryFile, encoding: .utf8) else {
            entries = []
            return
        }
        // Parse entries — each starts with "### "
        entries = content.components(separatedBy: "\n### ")
            .dropFirst() // skip header
            .map { "### " + $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func addEntry(_ fact: String, category: String = "observation") {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        let timestamp = formatter.string(from: Date())

        let entry = "### \(timestamp) — \(category)\n\(fact)\n"

        // Prepend to file (newest at top, after header)
        ensureFileExists()
        guard var content = try? String(contentsOfFile: memoryFile, encoding: .utf8) else { return }

        // Find the "---" separator after the header
        if let separatorRange = content.range(of: "---\n") {
            let insertPoint = separatorRange.upperBound
            content.insert(contentsOf: "\n" + entry, at: insertPoint)
        } else {
            content += "\n" + entry
        }

        try? content.write(toFile: memoryFile, atomically: true, encoding: .utf8)
        entries.insert(entry, at: 0)
    }

    // Returns the most recent entries as context for the LLM
    func getMemorySummary(limit: Int = 15) -> String {
        guard !entries.isEmpty else {
            return ""
        }

        let recent = entries.prefix(limit)
        let facts = recent.compactMap { entry -> String? in
            // Extract just the fact text (skip the "### timestamp — category" line)
            let lines = entry.split(separator: "\n", maxSplits: 1)
            guard lines.count > 1 else { return nil }
            return String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !facts.isEmpty else { return "" }
        return "What you remember about the user:\n" + facts.joined(separator: "\n")
    }

    func extractMemories(from conversation: String, usingOpenAI openAI: OpenAIClient, completion: @escaping () -> Void) {
        let existingContext = getMemorySummary(limit: 10)
        let prompt = """
        You are Blob's memory system. From this conversation, extract 1-2 facts worth remembering about the user.
        Keep each fact to ONE short line. Format: just the fact, no bullets or prefixes.
        Only extract genuinely useful things (preferences, habits, projects, relationships, opinions).
        Skip generic observations like "user is typing" or "user sent a message".
        \(existingContext.isEmpty ? "" : "\nYou already know:\n\(existingContext)\nDon't repeat things you already know.")

        Conversation: \(conversation)
        """

        openAI.chat(message: prompt) { [weak self] response, _ in
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count > 5 && !cleaned.lowercased().contains("no new") && !cleaned.lowercased().contains("nothing new") {
                self?.addEntry(cleaned, category: "conversation")
            }
            completion()
        }
    }

    // Legacy compatibility for ImportMemoriesView/ExportMemoriesView
    var memories: [LegacyMemory] {
        entries.compactMap { entry in
            let lines = entry.split(separator: "\n", maxSplits: 1)
            guard lines.count > 1 else { return nil }
            let fact = String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            return LegacyMemory(fact: fact, timestamp: Date(), category: "fact")
        }
    }

    func addMemory(_ fact: String, category: String = "fact") {
        addEntry(fact, category: category)
    }
}

struct LegacyMemory {
    let fact: String
    let timestamp: Date
    let category: String
}
