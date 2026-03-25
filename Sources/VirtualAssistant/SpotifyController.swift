import Foundation

class SpotifyController {
    func play() {
        runAppleScript("tell application \"Spotify\" to play")
    }

    func playSearch(query: String) {
        let webAPI = SpotifyWebAPI()
        webAPI.searchAndPlay(query: query)
    }

    func pause() {
        runAppleScript("tell application \"Spotify\" to pause")
    }

    func playPause() {
        runAppleScript("tell application \"Spotify\" to playpause")
    }

    func nextTrack() {
        runAppleScript("tell application \"Spotify\" to next track")
    }

    func previousTrack() {
        runAppleScript("tell application \"Spotify\" to previous track")
    }

    func getCurrentTrack(completion: @escaping (String) -> Void) {
        let script = """
        tell application "Spotify"
            set currentTrackName to name of current track
            set currentArtist to artist of current track
            return currentTrackName & " by " & currentArtist
        end tell
        """

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func setVolume(_ volume: Int) {
        let volumeClamped = max(0, min(100, volume))
        runAppleScript("tell application \"Spotify\" to set sound volume to \(volumeClamped)")
    }

    func getVolume(completion: @escaping (Int) -> Void) {
        let script = "tell application \"Spotify\" to return sound volume"

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            if let volume = Int(result.trimmingCharacters(in: .whitespaces)) {
                DispatchQueue.main.async {
                    completion(volume)
                }
            }
        }
    }

    private func runAppleScript(_ script: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        do {
            try task.run()
        } catch {
            print("❌ Spotify Error: \(error)")
        }
    }

    private func runAppleScriptAndReturn(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Spotify Error: \(error)")
            return ""
        }
    }
}
