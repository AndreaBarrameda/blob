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

    func chatWithScreenAwareness(message: String, completion: @escaping (String) -> Void) {
        guard let screenBase64 = ScreenCapture.captureScreenAsBase64() else {
            // Fallback to regular chat if screen capture fails
            chat(message: message, completion: completion)
            return
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let memorySummary = memory?.getMemorySummary() ?? ""
        let systemPrompt = "You are Blob, a cute AI assistant that can see the user's screen. You can see what they're doing and ask helpful, curious questions about it. Keep responses short (1-2 sentences). Be playful and observant! \(memorySummary)"

        let payload: [String: Any] = [
            "model": "gpt-5.4-nano",
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

    func chat(message: String, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let memorySummary = memory?.getMemorySummary() ?? ""
        let systemPrompt = "You are a cute and playful virtual assistant named Blob. Keep responses short (1-2 sentences) and friendly. You can see the user's system (battery, apps running). You can control Spotify - open songs, skip, pause. Be helpful and fun! When user asks to play something, open it in Spotify and say something like 'Found it! Opening X in Spotify - go ahead and hit play!' 🎵 \(memorySummary)"

        let payload: [String: Any] = [
            "model": "gpt-5.4-nano",
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
}
