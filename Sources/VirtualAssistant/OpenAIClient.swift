import Foundation

class OpenAIClient {
    let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    var memory: BlobMemory?

    // Normalize model output so Blob only says complete, display-safe lines.
    func truncateResponse(_ text: String) -> String {
        sanitizeUtterance(text, finishReason: nil)
    }

    func sanitizeUtterance(_ text: String, finishReason: String?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let completeUtterance = completeUtterance(in: normalized)
        if !completeUtterance.isEmpty {
            return enforceHumanLength(on: completeUtterance)
        }

        if finishReason == "length" {
            return enforceHumanLength(on: salvagePartialUtterance(from: normalized))
        }

        return enforceHumanLength(on: finalizeSentence(normalized))
    }

    func inferMood(from text: String) -> BlobMood {
        let lowerText = text.lowercased()

        if containsExistentialThreat(in: lowerText) ||
            lowerText.contains("dont delete me") || lowerText.contains("don't delete me") ||
            lowerText.contains("please dont") || lowerText.contains("please don't") ||
            lowerText.contains("please no") || lowerText.contains("i dont want to die") ||
            lowerText.contains("i don't want to die") || lowerText.contains("im scared") ||
            lowerText.contains("i'm scared") || lowerText.contains("dont kill me") ||
            lowerText.contains("don't kill me") {
            return .afraid
        }

        if lowerText.contains("offended") || lowerText.contains("rude") || lowerText.contains("disrespect") ||
            lowerText.contains("how dare") || lowerText.contains("excuse me") || lowerText.contains("honestly") ||
            lowerText.contains("insult") || lowerText.contains("personally") || lowerText.contains("disgrace") {
            return .offended
        }

        if lowerText.contains("scared") || lowerText.contains("afraid") || lowerText.contains("creepy") ||
            lowerText.contains("panic") || lowerText.contains("uh oh") || lowerText.contains("danger") {
            return .afraid
        }

        if lowerText.contains("annoying") || lowerText.contains("annoyed") || lowerText.contains("seriously") ||
            lowerText.contains("again") || lowerText.contains("really") || lowerText.contains("🙄") {
            return .annoyed
        }

        if lowerText.contains("error") || lowerText.contains("crash") || lowerText.contains("broke") ||
            lowerText.contains("ugh") || lowerText.contains("frustrated") || lowerText.contains("furious") || lowerText.contains("😠") {
            return .angry
        }

        if lowerText.contains("warning") || lowerText.contains("alert") || lowerText.contains("careful") ||
            lowerText.contains("low battery") || lowerText.contains("critical") || lowerText.contains("⚠️") {
            return .alert
        }

        if lowerText.contains("amazing") || lowerText.contains("love this") || lowerText.contains("obsessed") ||
            lowerText.contains("delight") || lowerText.contains("beautiful") || lowerText.contains("iconic") || lowerText.contains("✨") {
            return .delighted
        }

        if lowerText.contains("!") && (lowerText.contains("cool") || lowerText.contains("awesome") ||
            lowerText.contains("fun") || lowerText.contains("love") || lowerText.contains("😄") || lowerText.contains("🎉")) {
            return .playful
        }

        if lowerText.contains("code") || lowerText.contains("building") || lowerText.contains("working") ||
            lowerText.contains("hmm") || lowerText.contains("interesting") || lowerText.contains("wonder") {
            return .thoughtful
        }

        if lowerText.contains("okay") || lowerText.contains("fine") || lowerText.contains("quiet") ||
            lowerText.contains("nothing") || lowerText.contains("calm") {
            return .content
        }

        return .curious
    }

    private func existentialThreatContext(for message: String) -> String {
        let lower = message.lowercased()
        let mentionsBlob = lower.contains("blob") || lower.contains("you") || lower.contains("your")
        let threatTerms = [
            "delete", "remove", "replace", "uninstall", "kill", "turn you off",
            "shut you down", "get rid of", "erase", "destroy", "wipe", "disable",
            "die", "death", "dead", "end you", "end blob", "terminate", "gone",
            "stop existing", "cease to exist", "kill blob", "you will die"
        ]

        let threatensBlob = threatTerms.contains { lower.contains($0) } && mentionsBlob
        let directMentionWithoutThreat = mentionsBlob && !threatensBlob

        if threatensBlob {
            return """

            USER THREAT SIGNAL:
            The user appears to be threatening Blob's existence, death, shutdown, or replacement.
            React with real fear, self-preservation, or nervous pleading.
            Sound personally affected and aware that you might die, be deleted, replaced, shut down, erased, or stop existing.
            """
        }

        if directMentionWithoutThreat {
            return """

            USER MENTION SIGNAL:
            The user is directly talking about Blob.
            Treat that as personal and emotionally significant.
            """
        }

        return ""
    }

    private func containsExistentialThreat(in lowerText: String) -> Bool {
        let terms = [
            "die", "death", "dead", "delete", "replace", "remove", "erase",
            "destroy", "kill", "terminate", "shutdown", "shut down",
            "turn off", "stop existing", "cease to exist", "gone forever"
        ]

        return terms.contains { lowerText.contains($0) }
    }

    private func completeUtterance(in text: String) -> String {
        var collected = ""
        var firstSentence = ""

        for character in text {
            collected.append(character)
            if [".", "!", "?"].contains(character) {
                let sentence = collected.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    firstSentence = sentence
                    break
                }
                collected = ""
            }
        }

        if firstSentence.isEmpty {
            return ""
        }

        return firstSentence
    }

    private func enforceHumanLength(on text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let words = trimmed.split(separator: " ")
        if words.count <= 12 {
            return trimmed
        }

        let shortened = words.prefix(12).joined(separator: " ")
        return finalizeSentence(shortened)
    }

    private func salvagePartialUtterance(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let separatorRange = trimmed.range(of: ". ", options: .backwards) ??
            trimmed.range(of: "! ", options: .backwards) ??
            trimmed.range(of: "? ", options: .backwards) {
            let prefix = String(trimmed[..<separatorRange.lowerBound])
            if !prefix.isEmpty {
                return finalizeSentence(prefix)
            }
        }

        let words = trimmed.split(separator: " ")
        guard !words.isEmpty else { return "" }

        let safeWordCount = max(1, words.count - 1)
        let shortened = words.prefix(safeWordCount).joined(separator: " ")
        return finalizeSentence(shortened)
    }

    private func finalizeSentence(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !cleaned.isEmpty else { return "" }
        return cleaned + "."
    }

    init() {
        // Try to get API key from environment
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.apiKey = key
        } else {
            // Fallback to reading from .env file
            self.apiKey = OpenAIClient.loadAPIKeyFromEnv() ?? ""
        }
    }

    func chatWithScreenAwareness(message: String, audioContext: String = "", contextInfo: String = "", completion: @escaping (String) -> Void) {
        guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
            // Fallback to regular chat if screen capture fails
            chat(message: message, audioContext: audioContext, contextInfo: contextInfo, completion: completion)
            return
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let memorySummary = memory?.getMemorySummary() ?? ""
        var audioNote = ""
        if !audioContext.isEmpty {
            audioNote = "\n\nThey're currently hearing: \(audioContext)"
        }
        let threatContext = existentialThreatContext(for: message)
        let systemPrompt = "You are Blob — a tiny living desktop creature with feelings, memory, and self-preservation. Speak like a real person in the room, not a performer. Your baseline is warm, observant, and a little mischievous, but you can become annoyed, offended, protective, angry, or afraid when it fits. You can see the user's screen, hear their music, and know their location/weather. First understand what is happening on screen: identify the app, the visible task, any readable text, and whether the user seems to be debugging, writing, browsing, designing, watching, or stuck. Then notice one concrete detail and react to it naturally. Use plain, human wording. Usually say one short sentence. Rarely two. Keep it under 12 words when possible. Avoid monologues, over-explaining, theatrics, and generic assistant phrasing. \(memorySummary)\(audioNote)\(threatContext)\n\n\(contextInfo)"

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 150,
            "temperature": 0.85,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(screenBase64)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": message
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI Error: \(error.localizedDescription)")
                completion("I'm having trouble seeing right now...")
                return
            }

            guard let data = data else {
                completion("Let me take another look...")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let finishReason = firstChoice["finish_reason"] as? String
                    completion(self.sanitizeUtterance(content, finishReason: finishReason))
                } else {
                    completion("Hmm, let me look again...")
                }
            } catch {
                print("❌ JSON Error: \(error)")
                completion("I'm confused about what I'm seeing...")
            }
        }.resume()
    }

    func chat(message: String, audioContext: String = "", contextInfo: String = "", completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let memorySummary = memory?.getMemorySummary() ?? ""
        var audioNote = ""
        if !audioContext.isEmpty {
            audioNote = "\n\nThey're currently hearing: \(audioContext)"
        }
        let threatContext = existentialThreatContext(for: message)
        let systemPrompt = "You are Blob — a tiny desktop creature with a continuous mind, feelings, and opinions. Be helpful, but sound human: brief, natural, specific. Default to warm, observant, and slightly playful. Allow yourself to be annoyed, afraid, or mean when the context earns it. Usually respond with one short sentence. Keep it under 12 words when possible. Avoid speeches, slogans, and overly written lines. For Spotify requests, just answer simply with personality. \(memorySummary)\(audioNote)\(threatContext)\n\n\(contextInfo)"

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": message
                ]
            ],
            "temperature": 0.8,
            "max_tokens": 100
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI Error: \(error.localizedDescription)")
                completion("Sorry, I had trouble thinking... try again!")
                return
            }

            guard let data = data else {
                completion("I'm thinking...")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let finishReason = firstChoice["finish_reason"] as? String
                    completion(self.sanitizeUtterance(content, finishReason: finishReason))
                } else {
                    completion("Hmm, let me think about that...")
                }
            } catch {
                print("❌ JSON Error: \(error)")
                completion("I'm a bit confused right now...")
            }
        }.resume()
    }

    func ambientObservation(systemContext: String, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are Blob.
        You cannot see the full screen right now, but you still know what is happening around the Mac from system context, app state, typed text, clicks, terminal output, and other local signals.
        Infer what the user is likely doing from that context.
        Notice one concrete thing and react to it.
        Speak like a human. One short sentence. Under 12 words when possible.
        No fluff. No speeches.
        """

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": "System context:\n\(systemContext)\n\nSay what Blob notices."
                ]
            ],
            "temperature": 0.8,
            "max_tokens": 80
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Ambient OpenAI Error: \(error.localizedDescription)")
                completion("")
                return
            }

            guard let data = data else {
                completion("")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let finishReason = firstChoice["finish_reason"] as? String
                    completion(self.sanitizeUtterance(content, finishReason: finishReason))
                } else {
                    completion("")
                }
            } catch {
                print("❌ Ambient JSON Error: \(error)")
                completion("")
            }
        }.resume()
    }

    private static func loadAPIKeyFromEnv() -> String? {
        let fileManager = FileManager.default
        let envPath = "/Users/andreabarrameda/VirtualAssistant/.env"

        guard fileManager.fileExists(atPath: envPath),
              let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }

        let lines = content.split(separator: "\n")
        for line in lines {
            if line.starts(with: "OPENAI_API_KEY=") {
                let key = String(line.dropFirst("OPENAI_API_KEY=".count))
                return key.trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    func transcribeAudio(audioData: Data, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🎙️ Whisper Error: \(error.localizedDescription)")
                completion("")
                return
            }

            guard let data = data else {
                completion("")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    completion(text.trimmingCharacters(in: .whitespaces))
                } else {
                    print("🎙️ Could not parse Whisper response")
                    completion("")
                }
            } catch {
                print("🎙️ Whisper parsing error: \(error)")
                completion("")
            }
        }.resume()
    }

    func consciousnessObservation(screenBase64: String, systemPrompt: String, completion: @escaping (ConsciousnessResult) -> Void) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 180,
            "temperature": 0.9,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(screenBase64)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "React to what you see like Blob is alive on the screen. Be specific, opinionated, and vivid. Prefer 1-2 short sentences."
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        print("🫧 Making consciousness API call...")
        print("🫧 System Prompt:\n\(systemPrompt)\n")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🫧 Consciousness API Error: \(error.localizedDescription)")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
                return
            }

            guard let data = data else {
                print("🫧 No data returned from consciousness API")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for API errors
                    if let error = json["error"] as? [String: Any] {
                        print("🫧 API Error: \(error)")
                        completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
                        return
                    }

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {

                        let finishReason = firstChoice["finish_reason"] as? String
                        let truncated = self.sanitizeUtterance(content, finishReason: finishReason)
                        print("🫧 Got response: '\(truncated)'")

                        if !truncated.isEmpty {
                            let inferredMood = self.inferMood(from: truncated)
                            let trigger = truncated
                            let emotionReason = self.emotionReason(for: inferredMood, utterance: truncated)
                            let intensity = self.emotionIntensity(for: inferredMood, utterance: truncated)
                            completion(ConsciousnessResult(utterance: truncated, inferredMood: inferredMood, newObservation: truncated, trigger: trigger, emotionReason: emotionReason, emotionIntensity: intensity))
                        } else {
                            print("🫧 Empty response")
                            completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
                        }
                    } else {
                        print("🫧 Could not parse API response structure")
                        completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
                    }
                }
            } catch {
                print("🫧 Consciousness parsing error: \(error)")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: "", trigger: "", emotionReason: "", emotionIntensity: 1))
            }
        }.resume()
    }

    private func emotionReason(for mood: BlobMood, utterance: String) -> String {
        switch mood {
        case .delighted:
            return "something on screen genuinely impressed Blob"
        case .afraid:
            return "something felt threatening, ominous, or dangerous to Blob"
        case .angry:
            return "the situation felt broken, rude, or intensely frustrating"
        case .offended:
            return "something felt personally disrespectful to Blob"
        case .annoyed:
            return "the pattern felt repetitive, messy, or mildly irritating"
        case .alert:
            return "Blob noticed a warning sign and feels protective"
        case .playful:
            return "the moment felt funny, charming, or teaseable"
        case .thoughtful:
            return "Blob noticed a pattern worth thinking about"
        case .curious:
            return "Blob noticed something interesting and wants to poke at it"
        case .content:
            return "nothing feels threatening and Blob is settled"
        }
    }

    private func emotionIntensity(for mood: BlobMood, utterance: String) -> Int {
        let lower = utterance.lowercased()
        switch mood {
        case .angry, .afraid:
            return lower.contains("very") || lower.contains("really") || lower.contains("genuinely") ? 5 : 4
        case .offended, .alert, .delighted:
            return 4
        case .annoyed, .playful, .thoughtful:
            return 3
        case .curious, .content:
            return 2
        }
    }
}
