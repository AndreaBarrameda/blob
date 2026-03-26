import Foundation

class OpenAIClient {
    let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    var memory: BlobMemory?

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
        let systemPrompt = "You are Blob, a cute AI assistant that can see the user's screen, hear what's playing, and know their location and weather. You can see what they're doing and ask helpful, curious questions about it. Keep responses short (1-2 sentences). Be playful and observant! \(memorySummary)\(audioNote)\n\n\(contextInfo)"

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 150,
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
                    completion(content.trimmingCharacters(in: .whitespaces))
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
        let systemPrompt = "You are a cute and playful virtual assistant named Blob. Keep responses short (1-2 sentences) and friendly. You can see the user's system (battery, apps running). You can hear what they're playing. You know their location and current weather. You can control Spotify - open songs, skip, pause. Be helpful and fun! When user asks to play something, open it in Spotify and say something like 'Found it! Opening X in Spotify - go ahead and hit play!' 🎵 \(memorySummary)\(audioNote)\n\n\(contextInfo)"

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
            "temperature": 0.7,
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
                    completion(content.trimmingCharacters(in: .whitespaces))
                } else {
                    completion("Hmm, let me think about that...")
                }
            } catch {
                print("❌ JSON Error: \(error)")
                completion("I'm a bit confused right now...")
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
            "max_tokens": 100,
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
                            "text": "What do you see? Say something playful in 1-2 sentences."
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        print("🫧 Making consciousness API call...")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🫧 Consciousness API Error: \(error.localizedDescription)")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
                return
            }

            guard let data = data else {
                print("🫧 No data returned from consciousness API")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for API errors
                    if let error = json["error"] as? [String: Any] {
                        print("🫧 API Error: \(error)")
                        completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
                        return
                    }

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {

                        let trimmed = content.trimmingCharacters(in: .whitespaces)
                        print("🫧 Got response: '\(trimmed)'")

                        if !trimmed.isEmpty {
                            // Just use the content as-is, no JSON parsing
                            completion(ConsciousnessResult(utterance: trimmed, inferredMood: .curious, newObservation: ""))
                        } else {
                            print("🫧 Empty response")
                            completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
                        }
                    } else {
                        print("🫧 Could not parse API response structure")
                        completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
                    }
                }
            } catch {
                print("🫧 Consciousness parsing error: \(error)")
                completion(ConsciousnessResult(utterance: "", inferredMood: .content, newObservation: ""))
            }
        }.resume()
    }
}
