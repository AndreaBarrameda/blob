import Foundation

class OpenAIClient {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"

    init() {
        // Try to get API key from environment
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.apiKey = key
        } else {
            // Fallback to reading from .env file
            self.apiKey = OpenAIClient.loadAPIKeyFromEnv() ?? ""
        }
    }

    func chat(message: String, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a cute and playful virtual assistant named Blob. Keep responses short (1-2 sentences) and friendly. You can see the user's system (battery, apps running). You can control Spotify - play songs, skip, pause. Be helpful and fun! When user asks to play something, be excited and confirm you'll play it!"
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
