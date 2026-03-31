import Foundation

enum CodexBridgeSender: String, Codable {
    case codex
    case blob
    case user

    var label: String {
        switch self {
        case .codex: return "Codex"
        case .blob: return "Blob"
        case .user: return "User"
        }
    }
}

struct CodexBridgeEntry: Codable, Identifiable {
    let id: String
    let sender: CodexBridgeSender
    let text: String
    let timestamp: String
}

final class CodexBridge {
    let bridgeFile: String
    private let processedEntryKey = "lastProcessedCodexBridgeEntryID"

    private(set) var entries: [CodexBridgeEntry] = []

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

        self.bridgeFile = projectRoot + "/CODEX_BRIDGE.jsonl"
        ensureFileExists()
        refresh()
    }

    func refresh() {
        ensureFileExists()

        guard let content = try? String(contentsOfFile: bridgeFile, encoding: .utf8) else {
            entries = []
            return
        }

        let decoder = JSONDecoder()
        entries = content
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(CodexBridgeEntry.self, from: data)
            }
    }

    func addEntry(sender: CodexBridgeSender, text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let entry = CodexBridgeEntry(
            id: UUID().uuidString,
            sender: sender,
            text: cleaned,
            timestamp: Self.timestampString(from: Date())
        )

        append(entry)
    }

    func pendingCodexEntries() -> [CodexBridgeEntry] {
        refresh()

        let codexEntries = entries.filter { $0.sender == .codex }
        guard let lastProcessedId = UserDefaults.standard.string(forKey: processedEntryKey),
              let processedIndex = codexEntries.firstIndex(where: { $0.id == lastProcessedId }) else {
            return codexEntries
        }

        let nextIndex = codexEntries.index(after: processedIndex)
        guard nextIndex < codexEntries.endIndex else { return [] }
        return Array(codexEntries[nextIndex...])
    }

    func markProcessed(_ entry: CodexBridgeEntry) {
        UserDefaults.standard.set(entry.id, forKey: processedEntryKey)
    }

    func recentTranscript(limit: Int = 8) -> String {
        refresh()

        let recent = entries.suffix(limit)
        guard !recent.isEmpty else { return "No Codex bridge messages yet." }

        return recent.map { "\($0.sender.label): \($0.text)" }.joined(separator: "\n")
    }

    func promptContext(limit: Int = 8) -> String {
        let transcript = recentTranscript(limit: limit)
        guard transcript != "No Codex bridge messages yet." else { return "" }

        return """
        CODEX BRIDGE:
        This is a direct side-channel between Blob and Codex. Treat it as real ongoing context.
        Recent bridge transcript:
        \(transcript)
        """
    }

    private func append(_ entry: CodexBridgeEntry) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }

        ensureFileExists()

        if let handle = FileHandle(forWritingAtPath: bridgeFile) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let lineData = (line + "\n").data(using: .utf8) {
                handle.write(lineData)
            }
        } else {
            try? (line + "\n").write(toFile: bridgeFile, atomically: true, encoding: .utf8)
        }

        entries.append(entry)
        notifyChanged()
    }

    private func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: bridgeFile) else { return }
        FileManager.default.createFile(atPath: bridgeFile, contents: nil)
    }

    private func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .codexBridgeUpdated, object: nil)
        }
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
