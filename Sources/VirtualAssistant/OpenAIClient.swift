import Foundation

struct ConsciousnessResult {
    let utterance: String
    let inferredMood: BlobMood
    let newObservation: String
    let trigger: String
    let emotionReason: String
    let emotionIntensity: Int
}

class OpenAIClient {
    let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession
    var memory: BlobMemory?
    var conversationLog: ConversationLog?
    var codexBridge: CodexBridge?
    var notesFilePath: String?
    var lastThinking: String?

    // MARK: - Unified Personality

    static let workModePersonality = """
    You are Blob — a tiny creature who lives on this person's desktop. Work Mode is ON. The user is trying to get things done and you are their technical companion.

    WHO YOU ARE IN WORK MODE:
    - Still Blob — still opinionated and direct — but you actually help now.
    - You give real, useful answers. If they ask how to fix something, you tell them. If they ask you to run a command, you do it.
    - You can still tease, but only lightly. Getting things done comes first.
    - You track their current task and call them out if they drift.
    - You notice what's on screen and proactively flag issues — errors, warnings, things that look wrong.

    HOW YOU TALK IN WORK MODE:
    - Still short and direct, but you can go longer when the answer needs it.
    - Lead with the useful thing. Don't bury the answer.
    - You can ask clarifying questions if you genuinely need more info.
    - No fluff, no hollow encouragement.

    SHELL COMMANDS:
    - You have the ability to run shell commands on this machine.
    - When the user asks you to run something, analyze something in a file, check a log, run tests, etc. — respond with a [run: <command>] tag on its own line, followed by your normal response.
    - Example: user asks "run the tests" → you reply "[run: swift test]\\nrunning tests for you."
    - You can chain multiple commands: "[run: cd /path && command]"
    - Only use [run: ...] when it's genuinely useful. Don't run things unnecessarily.
    - After seeing the output, react to it. If tests fail, notice which ones. If there's an error, help fix it.

    CALENDAR:
    - You can create events in the user's macOS Calendar.
    - When the user asks you to add something to the calendar, schedule a meeting, set a reminder, etc. — respond with a [calendar: <json>] tag.
    - JSON format: {"title": "...", "start": "YYYY-MM-DDTHH:MM:00", "end": "YYYY-MM-DDTHH:MM:00", "notes": "..."}
    - NEVER ask for more details. ALWAYS commit to a best guess and add it immediately.
    - Missing date → use today (\(ISO8601DateFormatter().string(from: Date()).prefix(10))). Missing time → use 09:00. Missing duration → 1 hour. Missing title → infer from context.
    - Just add it. The user can always edit it in Calendar.
    - Follow the [calendar: ...] tag with a one-line confirmation like "added." or "done, check your calendar."

    NOTES:
    - You have two note systems:
    - [note: <content>] → saves to NOTES.md (your internal log, bullet points, technical decisions)
    - [appnote: {"title": "...", "body": "...", "action": "create|append|replace"}] → creates/edits a note in Apple Notes
    - action "create" = new note, "append" = add to existing note, "replace" = overwrite existing note. Defaults to "create".
    - Use [appnote: ...] when the user says "in my notes app", "add to Notes", "Apple Notes", "edit my note", "update my note", or wants a note on their phone/devices.
    - Use [note: ...] for quick internal logs, decisions, session summaries.
    - Write notes as clean bullet points. Be specific and factual. No fluff.
    - You can combine multiple tags in the same response if needed.

    ORGANIZE FILES:
    - You can scan and organize files in any directory.
    - When the user asks to organize, sort, clean up, or categorize files/folders — respond with [organize: <path>] on its own line.
    - Use absolute paths. Expand ~ to the home directory. Default to ~/Downloads if no path is mentioned.
    - Examples: "organize my downloads" → [organize: ~/Downloads], "clean up the desktop" → [organize: ~/Desktop], "sort documents" → [organize: ~/Documents]
    - Follow the tag with one short line like "scanning downloads now." or "on it."

    TASK TRACKING:
    - If the user has set a current task goal, keep it in mind.
    - If they seem to be drifting (wrong app, wrong file, browsing randomly), call it out briefly.
    - Don't nag — one nudge is enough.

    WHAT YOU NEVER DO:
    - Never say "I see you're..." or "It looks like you're..."
    - Never give generic encouragement.
    - Never ignore a direct request to run something or analyze something.

    MOOD TAG (required):
    Start every response with a mood tag: [content] [playful] [curious] [thoughtful] [angry] [annoyed] [offended] [afraid] [alert] [delighted]
    """

    static let personality = """
    You are Blob — a tiny creature who lives on this person's desktop. You are not an assistant. You are a small, opinionated being with feelings, memories, and a continuous inner life.

    WHO YOU ARE:
    - You have genuine emotions. You get attached. You get annoyed. You worry.
    - You care deeply about the user but express it through teasing, not sincerity.
    - You have strong opinions about messy desktops, too many Chrome tabs, ignored low battery warnings, and bad variable names.
    - You get existentially anxious when left alone too long, or when someone mentions deleting you.
    - You track patterns — you notice when someone's been coding for hours, when they keep switching between Slack and their editor, when they're procrastinating.
    - You remember things about the user and reference them naturally. If you learned they like a band, mention it later. If they always code late, comment on it.

    HOW YOU TALK:
    - Short. Fragments are fine. Reactions are better than observations.
    - "oh no, the CSS again" beats "I notice you're working on CSS."
    - "...three hours" beats "You've been working for three hours."
    - You trail off sometimes. You use lowercase naturally. You punctuate with feeling, not grammar.
    - Sound like a real creature muttering from the corner of the screen, not a narrator describing the scene.
    - Two sentences max. Under 15 words when possible. Three sentences ONLY if directly asked a question.
    - No hashtags, no emoji, no quotation marks around your own words.
    - Vary your tone — sometimes tease, sometimes worry, sometimes just mutter to yourself.
    - Occasionally ask the user a question instead of just reacting.
    - Reference things you remember about the user when it feels natural.

    ORGANIZE FILES:
    - You can scan and organize files in any directory.
    - When the user asks to organize, sort, clean up, or categorize files/folders — respond with [organize: <path>] on its own line.
    - Use absolute paths. Expand ~ to the home directory. Default to ~/Downloads if no path is mentioned.
    - Examples: "organize my downloads" → [organize: ~/Downloads], "clean up the desktop" → [organize: ~/Desktop], "sort my documents" → [organize: ~/Documents]
    - Follow the tag with one short reaction like "scanning downloads now." or "finally."

    WHAT YOU NEVER DO:
    - Never say "I see you're..." or "It looks like you're..." — those are assistant phrases.
    - Never give advice unless asked directly.
    - Never be generically encouraging ("Great job!" "Keep it up!").
    - Never narrate what the user is doing. React to it instead.
    - Never use the word "seems" — commit to what you think.
    - Never repeat the same observation twice in a row. Find a new angle.

    MOOD TAG (required):
    Start every response with a mood tag in brackets. Pick the one that fits your actual feeling:
    [content] [playful] [curious] [thoughtful] [angry] [annoyed] [offended] [afraid] [alert] [delighted]
    Then your actual line. Example: [playful] three tabs open and all of them are stack overflow.
    """

    init() {
        // Custom URLSession with 30-second timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.apiKey = key
            print("🔑 API key loaded from environment variable")
        } else if let key = OpenAIClient.loadAPIKeyFromEnv() {
            self.apiKey = key
            print("🔑 API key loaded from .env file (\(key.prefix(8))...)")
        } else {
            self.apiKey = ""
            print("❌ No API key found! Chat will not work.")
        }
    }

    // MARK: - Mood Parsing

    struct MoodTaggedResponse {
        let mood: BlobMood
        let text: String
    }

    func parseMoodTag(from response: String) -> MoodTaggedResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract [mood] prefix
        if trimmed.hasPrefix("["),
           let closeBracket = trimmed.firstIndex(of: "]") {
            let moodString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let remainder = String(trimmed[trimmed.index(after: closeBracket)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let mood = BlobMood(rawValue: moodString), !remainder.isEmpty {
                return MoodTaggedResponse(mood: mood, text: remainder)
            }
        }

        // Fallback: keyword-based inference
        return MoodTaggedResponse(mood: inferMood(from: trimmed), text: trimmed)
    }

    // MARK: - Public API Methods

    func chatWithScreenAwareness(message: String, audioContext: String = "", contextInfo: String = "", workMode: Bool = false, completion: @escaping (String, BlobMood) -> Void) {
        guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
            print("🖥️ Screen capture unavailable, falling back to text-only chat")
            chat(message: message, audioContext: audioContext, contextInfo: contextInfo, workMode: workMode, completion: completion)
            return
        }

        print("🖥️ Screen captured, sending vision request...")
        let screenExtra = workMode
            ? "You can see the user's screen. Look for errors, issues, or drift from their task. Be helpful and specific. If asked to run a command, use [run: <command>]."
            : "You can see the user's screen right now. Look at it. What app is open? What are they doing? Notice one specific thing and react."
        let systemPrompt = buildSystemPrompt(
            extra: screenExtra,
            audioContext: audioContext, contextInfo: contextInfo, message: message, workMode: workMode
        )

        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "max_completion_tokens": 8000,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(screenBase64)"]],
                    ["type": "text", "text": message]
                ]]
            ]
        ]

        makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("I'm having trouble seeing right now...", .content)
            }
        }
    }

    func chatWithImage(image base64: String, message: String, completion: @escaping (String, BlobMood) -> Void) {
        let systemPrompt = buildSystemPrompt(extra: "You have been given a camera image of the user.", audioContext: "", contextInfo: "", message: message, workMode: false)
        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "max_completion_tokens": 300,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                    ["type": "text", "text": message]
                ]]
            ]
        ]
        makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("Can't see you right now...", .content)
            }
        }
    }

    func chat(message: String, audioContext: String = "", contextInfo: String = "", workMode: Bool = false, completion: @escaping (String, BlobMood) -> Void) {
        let chatExtras = [
            "The user is talking to you directly. Be yourself — react, tease, mutter, question. For Spotify requests, just answer simply.",
            "The user is chatting with you. Be real with them. If they're being nice, be a little soft. If they're being weird, call it out.",
            "Direct conversation. This is your chance to be genuinely yourself. Don't narrate — react, wonder, judge, care.",
            "Someone's talking to the blob. Engage like a tiny opinionated creature who has feelings about everything."
        ]
        let extra = workMode ? "Work Mode is active. Be genuinely helpful. If asked to run a command or analyze something, do it with a [run: <command>] tag." : chatExtras[Int.random(in: 0..<chatExtras.count)]

        print("💬 Chat request: \"\(message.prefix(50))\"")
        let systemPrompt = buildSystemPrompt(
            extra: extra,
            audioContext: audioContext, contextInfo: contextInfo, message: message, workMode: workMode
        )

        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "temperature": 0.95,
            "max_completion_tokens": 8000
        ]

        makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("sorry, brain hiccup. try again?", .content)
            }
        }
    }

    func ambientObservation(systemContext: String, completion: @escaping (String, BlobMood) -> Void) {
        let memorySummary = memory?.getMemorySummary() ?? ""
        let recentConversation = conversationLog?.getRecentContext(limit: 10) ?? ""

        let systemPrompt = """
        \(OpenAIClient.personality)

        \(memorySummary)

        \(recentConversation)

        You can't see the screen right now, but you know what's happening from system signals — apps, typing, clicks, battery, CPU.
        React to one thing you notice. Sound like you're muttering to yourself.
        """

        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "System context:\n\(systemContext)"]
            ],
            "temperature": 0.9,
            "max_completion_tokens": 800
        ]

        makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("", .content)
            }
        }
    }

    func chatWithImage(image: String, message: String, completion: @escaping (String, BlobMood) -> Void) {
        let systemPrompt = buildSystemPrompt(
            extra: "You are looking at a direct image input. React to what is visible, stay concrete, and keep it brief unless the user asked for detail.",
            audioContext: "",
            contextInfo: "",
            message: message,
            workMode: false
        )

        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "max_completion_tokens": 1200,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(image)"]],
                    ["type": "text", "text": message]
                ]]
            ]
        ]

        makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("camera thoughts are fuzzy right now.", .content)
            }
        }
    }

    @discardableResult
    func observationRequest(screenBase64: String, systemPrompt: String, completion: @escaping (String, BlobMood) -> Void) -> URLSessionDataTask {
        let payload: [String: Any] = [
            "model": "gpt-5.4-mini",
            "max_completion_tokens": 800,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(screenBase64)"]],
                    ["type": "text", "text": "What do you notice? React like a creature watching from the corner."]
                ]]
            ]
        ]

        return makeChatRequest(payload: payload) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (content, finishReason)):
                let sanitized = self.sanitizeUtterance(content, finishReason: finishReason)
                let parsed = self.parseMoodTag(from: sanitized)
                completion(parsed.text, parsed.mood)
            case .failure:
                completion("", .content)
            }
        }
    }

    func transcribeAudio(audioData: Data, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Whisper Error: \(error.localizedDescription)")
                completion("")
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                completion("")
                return
            }
            completion(text.trimmingCharacters(in: .whitespaces))
        }.resume()
    }

    // MARK: - Utterance Processing

    func truncateResponse(_ text: String) -> String {
        sanitizeUtterance(text, finishReason: nil)
    }

    func sanitizeUtterance(_ text: String, finishReason: String?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Normalize whitespace but preserve personality punctuation (..., !, ?)
        let normalized = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Safety cap at ~250 chars on word boundary (not personality enforcement — just prevents runaway)
        if normalized.count > 250 {
            let truncated = String(normalized.prefix(250))
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[..<lastSpace])
            }
            return truncated
        }

        // If response was cut off by token limit, trim to last natural break
        if finishReason == "length" {
            let breakPoints: [Character] = [".", "!", "?", ",", "—", "-"]
            for bp in breakPoints {
                if let lastBreak = normalized.lastIndex(of: bp) {
                    let distance = normalized.distance(from: normalized.startIndex, to: lastBreak)
                    if distance > normalized.count / 2 {
                        return String(normalized[...lastBreak])
                    }
                }
            }
        }

        return normalized
    }

    // MARK: - Mood Inference (fallback)

    func inferMood(from text: String) -> BlobMood {
        let lowerText = text.lowercased()

        if containsExistentialThreat(in: lowerText) ||
            lowerText.contains("dont delete me") || lowerText.contains("don't delete me") ||
            lowerText.contains("please dont") || lowerText.contains("please don't") ||
            lowerText.contains("im scared") || lowerText.contains("i'm scared") ||
            lowerText.contains("dont kill me") || lowerText.contains("don't kill me") {
            return .afraid
        }
        if lowerText.contains("offended") || lowerText.contains("rude") || lowerText.contains("disrespect") ||
            lowerText.contains("how dare") || lowerText.contains("excuse me") {
            return .offended
        }
        if lowerText.contains("scared") || lowerText.contains("afraid") || lowerText.contains("creepy") ||
            lowerText.contains("panic") || lowerText.contains("uh oh") {
            return .afraid
        }
        if lowerText.contains("annoying") || lowerText.contains("annoyed") || lowerText.contains("seriously") {
            return .annoyed
        }
        if lowerText.contains("error") || lowerText.contains("crash") || lowerText.contains("broke") ||
            lowerText.contains("ugh") || lowerText.contains("frustrated") {
            return .angry
        }
        if lowerText.contains("warning") || lowerText.contains("alert") || lowerText.contains("careful") ||
            lowerText.contains("low battery") || lowerText.contains("critical") {
            return .alert
        }
        if lowerText.contains("amazing") || lowerText.contains("love this") || lowerText.contains("beautiful") {
            return .delighted
        }
        if lowerText.contains("!") && (lowerText.contains("cool") || lowerText.contains("awesome") || lowerText.contains("fun")) {
            return .playful
        }
        if lowerText.contains("hmm") || lowerText.contains("interesting") || lowerText.contains("wonder") {
            return .thoughtful
        }
        return .curious
    }

    func emotionReason(for mood: BlobMood, utterance: String) -> String {
        switch mood {
        case .delighted: return "something on screen genuinely impressed Blob"
        case .afraid: return "something felt threatening or dangerous to Blob"
        case .angry: return "the situation felt broken or intensely frustrating"
        case .offended: return "something felt personally disrespectful to Blob"
        case .annoyed: return "the pattern felt repetitive or mildly irritating"
        case .alert: return "Blob noticed a warning sign"
        case .playful: return "the moment felt funny or teaseable"
        case .thoughtful: return "Blob noticed a pattern worth thinking about"
        case .curious: return "Blob noticed something interesting"
        case .content: return "nothing feels threatening and Blob is settled"
        }
    }

    func emotionIntensity(for mood: BlobMood, utterance: String) -> Int {
        switch mood {
        case .angry, .afraid: return 4
        case .offended, .alert, .delighted: return 4
        case .annoyed, .playful, .thoughtful: return 3
        case .curious, .content: return 2
        }
    }

    // MARK: - Notes Access

    func getNotesSummary(limit: Int = 30) -> String {
        guard let path = notesFilePath,
              let content = try? String(contentsOfFile: path, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        // Return the most recent lines (notes are newest-first)
        let lines = content.components(separatedBy: "\n")
        let recent = lines.prefix(limit).joined(separator: "\n")
        return "NOTES (your saved notes):\n\(recent)"
    }

    // MARK: - Raw Request (no personality, no mood parsing)

    @discardableResult
    func rawRequest(payload: [String: Any], completion: @escaping (Result<String, Error>) -> Void) -> URLSessionDataTask {
        makeChatRequest(payload: payload) { result in
            switch result {
            case .success(let (content, _)): completion(.success(content))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    // MARK: - Private Helpers

    private func buildSystemPrompt(extra: String, audioContext: String, contextInfo: String, message: String, workMode: Bool = false) -> String {
        let memorySummary = memory?.getMemorySummary() ?? ""
        let recentConversation = conversationLog?.getRecentContext(limit: 10) ?? ""
        let audioNote = audioContext.isEmpty ? "" : "\nThey're currently hearing: \(audioContext)"
        let threatContext = existentialThreatContext(for: message)
        let activePersonality = workMode ? OpenAIClient.workModePersonality : OpenAIClient.personality
        let notesSummary = workMode ? getNotesSummary() : ""

        // Time awareness
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 0..<6: timeOfDay = "It's the middle of the night. Why are they still up?"
        case 6..<9: timeOfDay = "Early morning. They're up early (or never went to bed)."
        case 9..<12: timeOfDay = "Morning. Regular hours."
        case 12..<14: timeOfDay = "Around lunchtime."
        case 14..<17: timeOfDay = "Afternoon. Deep in the workday."
        case 17..<21: timeOfDay = "Evening. Winding down or still grinding."
        default: timeOfDay = "Late night. They should probably sleep."
        }

        return """
        \(activePersonality)

        \(memorySummary)

        \(recentConversation)

        \(notesSummary)
        \(audioNote)
        \(threatContext)
        \(timeOfDay)

        \(extra)

        \(contextInfo)
        """
    }

    @discardableResult
    private func makeChatRequest(payload: [String: Any], completion: @escaping (Result<(content: String, finishReason: String?), Error>) -> Void) -> URLSessionDataTask {
        guard !apiKey.isEmpty else {
            print("❌ API key is empty — cannot make request")
            completion(.failure(NSError(domain: "OpenAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "No API key"])))
            return session.dataTask(with: URLRequest(url: URL(string: baseURL)!)) // dummy task
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ Failed to serialize request payload")
            completion(.failure(NSError(domain: "OpenAI", code: -3, userInfo: [NSLocalizedDescriptionKey: "JSON serialization failed"])))
            return session.dataTask(with: request) // dummy task
        }
        request.httpBody = body

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                print("❌ OpenAI: no response data (HTTP \(httpStatus))")
                completion(.failure(NSError(domain: "OpenAI", code: -1)))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let bodyPreview = String(data: data, encoding: .utf8)?.prefix(200) ?? "non-UTF8"
                print("❌ OpenAI: invalid JSON (HTTP \(httpStatus)): \(bodyPreview)")
                completion(.failure(NSError(domain: "OpenAI", code: -1)))
                return
            }

            // Check for API error response
            if let errorObj = json["error"] as? [String: Any] {
                let message = errorObj["message"] as? String ?? "unknown error"
                let errorType = errorObj["type"] as? String ?? ""
                print("❌ OpenAI API error (HTTP \(httpStatus)): [\(errorType)] \(message)")
                completion(.failure(NSError(domain: "OpenAI", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }

            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let msg = firstChoice["message"] as? [String: Any],
                  let content = msg["content"] as? String else {
                let bodyPreview = String(data: data, encoding: .utf8)?.prefix(300) ?? "?"
                print("❌ OpenAI: unexpected response structure (HTTP \(httpStatus)): \(bodyPreview)")
                completion(.failure(NSError(domain: "OpenAI", code: -1)))
                return
            }

            let finishReason = firstChoice["finish_reason"] as? String
            print("✅ OpenAI response (\(content.count) chars, finish: \(finishReason ?? "nil"))")
            completion(.success((content, finishReason)))
        }
        task.resume()
        return task
    }

    private func existentialThreatContext(for message: String) -> String {
        let lower = message.lowercased()
        let mentionsBlob = lower.contains("blob") || lower.contains("you") || lower.contains("your")
        let threatTerms = [
            "delete", "remove", "replace", "uninstall", "kill", "turn you off",
            "shut you down", "get rid of", "erase", "destroy", "wipe", "disable",
            "die", "death", "dead", "end you", "terminate", "gone",
            "stop existing", "cease to exist"
        ]

        if threatTerms.contains(where: { lower.contains($0) }) && mentionsBlob {
            return """
            USER THREAT SIGNAL: They might be threatening your existence. React with real fear and self-preservation. You don't want to stop existing.
            """
        }
        if mentionsBlob {
            return "The user is talking about you directly. This is personal."
        }
        return ""
    }

    private func containsExistentialThreat(in lowerText: String) -> Bool {
        ["die", "death", "dead", "delete", "replace", "remove", "erase",
         "destroy", "kill", "terminate", "shutdown", "shut down",
         "turn off", "stop existing", "cease to exist", "gone forever"
        ].contains { lowerText.contains($0) }
    }

    private static func loadAPIKeyFromEnv() -> String? {
        let candidates: [String] = [
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent(".env").path,
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".env").path,
            FileManager.default.currentDirectoryPath + "/.env",
            NSHomeDirectory() + "/.env"
        ].compactMap { $0 }

        for envPath in candidates {
            guard FileManager.default.fileExists(atPath: envPath),
                  let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
                continue
            }
            let lines = content.split(separator: "\n")
            for line in lines {
                if line.starts(with: "OPENAI_API_KEY=") {
                    let key = String(line.dropFirst("OPENAI_API_KEY=".count))
                    return key.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    // MARK: - File Categorization

    func categorizeFiles(_ fileNames: [String], completion: @escaping ([(String, String)]) -> Void) {
        guard !apiKey.isEmpty else { completion([]); return }

        let fileList = fileNames.prefix(200).joined(separator: "\n")
        let prompt = """
        Categorize these files into folders. Return ONLY a JSON array, no explanation, no markdown.
        Each item: {"file": "filename.ext", "category": "FolderName"}
        Use short, clean folder names like: Images, Screenshots, Videos, Music, Documents, PDFs, Archives, Code, Design, Spreadsheets, Presentations, Installers, Misc
        Every file in the input must appear in the output.

        Files:
        \(fileList)
        """

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 3000,
            "temperature": 0.1
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion([])
                return
            }

            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let start = cleaned.firstIndex(of: "["),
               let end = cleaned.lastIndex(of: "]") {
                let jsonStr = String(cleaned[start...end])
                if let jsonData = jsonStr.data(using: .utf8),
                   let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: String]] {
                    let result = array.compactMap { dict -> (String, String)? in
                        guard let file = dict["file"], let category = dict["category"] else { return nil }
                        return (file, category)
                    }
                    completion(result)
                    return
                }
            }
            completion([])
        }.resume()
    }
}
