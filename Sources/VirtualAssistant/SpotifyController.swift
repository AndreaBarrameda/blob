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

    func getTrackInfo(completion: @escaping (_ trackName: String, _ artist: String, _ isPlaying: Bool) -> Void) {
        let script = """
        tell application "Spotify"
            set currentTrackName to name of current track
            set currentArtist to artist of current track
            set isPlaying to player state is playing
            return currentTrackName & "|" & currentArtist & "|" & isPlaying
        end tell
        """

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            let parts = result.split(separator: "|").map(String.init)

            let trackName = parts.count > 0 ? parts[0].trimmingCharacters(in: .whitespaces) : ""
            let artist = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            let isPlaying = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) == "true" : false

            DispatchQueue.main.async {
                completion(trackName, artist, isPlaying)
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

        let pipe = Pipe()
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMsg = String(data: data, encoding: .utf8), !errorMsg.isEmpty {
                    print("❌ Spotify Error: \(errorMsg)")
                } else {
                    print("❌ Spotify command failed (status: \(task.terminationStatus))")
                }
            }
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
