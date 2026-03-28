import Foundation
import AVFoundation

class ElevenLabsClient: NSObject, AVAudioPlayerDelegate {
    let apiKey: String
    let voiceId: String
    private var audioPlayer: AVAudioPlayer?
    private let session: URLSession
    private var onPlaybackComplete: (() -> Void)?
    var isEnabled: Bool = true

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        let keys = ElevenLabsClient.loadKeysFromEnv()
        self.apiKey = keys.apiKey
        self.voiceId = keys.voiceId

        if apiKey.isEmpty {
            print("🔊 ElevenLabs: no API key found — voice disabled")
        } else {
            print("🔊 ElevenLabs: loaded (voice: \(voiceId.prefix(8))...)")
        }
    }

    var isAvailable: Bool {
        isEnabled && !apiKey.isEmpty && !voiceId.isEmpty
    }

    /// Speak text aloud. Fire-and-forget — won't block. Calls completion when audio finishes playing.
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard isAvailable else {
            completion?()
            return
        }

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty, cleanText.count >= 3 else { return }

        let ttsStart = Date()
        print("🔊 Speaking: \"\(cleanText.prefix(50))\"")

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": cleanText,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.3,          // lower = more varied intonation
                "similarity_boost": 0.6,    // allow deviation for character
                "style": 0.7,              // high expressiveness
                "use_speaker_boost": true
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("🔊 ElevenLabs error: \(error.localizedDescription)")
                return
            }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, !data.isEmpty else {
                print("🔊 ElevenLabs: empty response (HTTP \(httpStatus))")
                return
            }

            guard httpStatus == 200 else {
                let body = String(data: data, encoding: .utf8)?.prefix(200) ?? "?"
                print("🔊 ElevenLabs error (HTTP \(httpStatus)): \(body)")
                return
            }

            let ttsMs = Int(Date().timeIntervalSince(ttsStart) * 1000)
            print("🔊 Audio received (\(data.count / 1024)KB) [elevenlabs: \(ttsMs)ms], playing...")
            self?.playAudio(data, completion: completion)
        }.resume()
    }

    private func playAudio(_ data: Data, completion: (() -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            do {
                self?.onPlaybackComplete = completion
                self?.audioPlayer = try AVAudioPlayer(data: data)
                self?.audioPlayer?.delegate = self
                self?.audioPlayer?.volume = 0.8
                self?.audioPlayer?.play()
            } catch {
                print("🔊 Audio playback error: \(error.localizedDescription)")
                completion?()
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onPlaybackComplete?()
        onPlaybackComplete = nil
    }

    /// Stop any currently playing speech
    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
        }
    }

    // MARK: - Key Loading

    private static func loadKeysFromEnv() -> (apiKey: String, voiceId: String) {
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

        var apiKey = ""
        var voiceId = ""

        for envPath in candidates {
            guard FileManager.default.fileExists(atPath: envPath),
                  let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
                continue
            }
            for line in content.split(separator: "\n") {
                if line.starts(with: "ELEVENLABS_API_KEY=") {
                    apiKey = String(line.dropFirst("ELEVENLABS_API_KEY=".count)).trimmingCharacters(in: .whitespaces)
                }
                if line.starts(with: "ELEVENLABS_VOICE_ID=") {
                    voiceId = String(line.dropFirst("ELEVENLABS_VOICE_ID=".count)).trimmingCharacters(in: .whitespaces)
                }
            }
            if !apiKey.isEmpty { break }
        }

        return (apiKey, voiceId)
    }
}
