import Foundation

class ConversationLog {
    let logFile: String
    private var recentCache: [Exchange] = []

    struct Exchange {
        let timestamp: String
        let type: String       // "chat", "observation", "ambient", "tap"
        let mood: String
        let userMessage: String? // only for chat
        let blobResponse: String
    }

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
        self.logFile = projectRoot + "/CONVERSATION.md"
        ensureFileExists()
        loadRecent()
    }

    private func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: logFile) else { return }
        let header = """
        # Blob Conversation Log

        Every exchange Blob has ever had. Newest at top.

        ---

        """
        try? header.write(toFile: logFile, atomically: true, encoding: .utf8)
        print("💬 Created CONVERSATION.md at \(logFile)")
    }

    // MARK: - Logging

    func logChat(userMessage: String, blobResponse: String, mood: String) {
        let entry = formatEntry(type: "chat", mood: mood, userMessage: userMessage, blobResponse: blobResponse)
        prependEntry(entry)
        cacheExchange(Exchange(
            timestamp: currentTimestamp(),
            type: "chat",
            mood: mood,
            userMessage: userMessage,
            blobResponse: blobResponse
        ))
    }

    func logObservation(blobResponse: String, mood: String) {
        let entry = formatEntry(type: "observation", mood: mood, userMessage: nil, blobResponse: blobResponse)
        prependEntry(entry)
        cacheExchange(Exchange(
            timestamp: currentTimestamp(),
            type: "observation",
            mood: mood,
            userMessage: nil,
            blobResponse: blobResponse
        ))
    }

    func logAmbient(blobResponse: String, mood: String) {
        let entry = formatEntry(type: "ambient", mood: mood, userMessage: nil, blobResponse: blobResponse)
        prependEntry(entry)
        cacheExchange(Exchange(
            timestamp: currentTimestamp(),
            type: "ambient",
            mood: mood,
            userMessage: nil,
            blobResponse: blobResponse
        ))
    }

    // MARK: - Reading Recent Context

    /// Returns the last N exchanges formatted for the LLM prompt
    func getRecentContext(limit: Int = 10) -> String {
        guard !recentCache.isEmpty else { return "" }

        let recent = recentCache.prefix(limit)
        let lines = recent.reversed().map { exchange -> String in
            if let userMsg = exchange.userMessage {
                return "User: \(userMsg)\nBlob [\(exchange.mood)]: \(exchange.blobResponse)"
            } else {
                return "Blob [\(exchange.mood)] (\(exchange.type)): \(exchange.blobResponse)"
            }
        }

        return "YOUR RECENT HISTORY (do NOT repeat these — find a new angle every time):\n" + lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func formatEntry(type: String, mood: String, userMessage: String?, blobResponse: String) -> String {
        let ts = currentTimestamp()
        if let userMsg = userMessage {
            return "### \(ts) — \(type) [\(mood)]\nUser: \(userMsg)\nBlob: \(blobResponse)\n"
        } else {
            return "### \(ts) — \(type) [\(mood)]\n\(blobResponse)\n"
        }
    }

    private func prependEntry(_ entry: String) {
        ensureFileExists()
        guard var content = try? String(contentsOfFile: logFile, encoding: .utf8) else { return }

        if let separatorRange = content.range(of: "---\n") {
            let insertPoint = separatorRange.upperBound
            content.insert(contentsOf: "\n" + entry, at: insertPoint)
        } else {
            content += "\n" + entry
        }

        try? content.write(toFile: logFile, atomically: true, encoding: .utf8)
    }

    private func cacheExchange(_ exchange: Exchange) {
        recentCache.insert(exchange, at: 0)
        if recentCache.count > 20 {
            recentCache = Array(recentCache.prefix(20))
        }
    }

    private func loadRecent() {
        guard let content = try? String(contentsOfFile: logFile, encoding: .utf8) else { return }

        let blocks = content.components(separatedBy: "\n### ")
            .dropFirst() // skip header
            .prefix(20)

        for block in blocks {
            let lines = block.split(separator: "\n", maxSplits: 3).map(String.init)
            guard !lines.isEmpty else { continue }

            // Parse header: "2026-03-28 21:30 — observation [playful]"
            let header = lines[0]
            let parts = header.components(separatedBy: " — ")
            guard parts.count >= 2 else { continue }

            let timestamp = parts[0].trimmingCharacters(in: .whitespaces)
            let rest = parts[1]

            // Extract type and mood from "observation [playful]"
            var type = "unknown"
            var mood = "content"
            if let bracketStart = rest.firstIndex(of: "["),
               let bracketEnd = rest.firstIndex(of: "]") {
                type = String(rest[..<bracketStart]).trimmingCharacters(in: .whitespaces)
                mood = String(rest[rest.index(after: bracketStart)..<bracketEnd])
            }

            // Parse body
            var userMessage: String? = nil
            var blobResponse = ""

            if lines.count >= 3 && lines[1].hasPrefix("User: ") {
                userMessage = String(lines[1].dropFirst("User: ".count))
                blobResponse = lines[2].hasPrefix("Blob: ") ? String(lines[2].dropFirst("Blob: ".count)) : lines[2]
            } else if lines.count >= 2 {
                blobResponse = lines[1]
            }

            guard !blobResponse.isEmpty else { continue }

            recentCache.append(Exchange(
                timestamp: timestamp,
                type: type,
                mood: mood,
                userMessage: userMessage,
                blobResponse: blobResponse
            ))
        }
    }
}
