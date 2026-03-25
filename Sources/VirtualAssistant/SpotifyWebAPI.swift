import Foundation
import AppKit

class SpotifyWebAPI {
    // Note: Using simplified approach with URI scheme
    // For full playback control, you'd need OAuth and device ID

    func searchAndPlay(query: String) {
        // Encode the search query for Spotify URI
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        // Use Spotify search scheme which works reliably
        let spotifySearchURI = "spotify:search:\(encodedQuery)"

        // Open with system default handler (Spotify)
        if let url = URL(string: spotifySearchURI) {
            NSWorkspace.shared.open(url)

            // Wait for Spotify to open search, then interact with UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.playFirstResult()
            }
        }
    }

    private func playFirstResult() {
        // Use AppleScript with UI Automation to click play on first result
        let script = """
        tell application "System Events"
            -- Focus Spotify window
            tell process "Spotify"
                set frontmost to true
                delay 0.5

                -- Press Enter to play the first search result
                key code 36
                delay 0.5
            end tell
        end tell
        """

        runAppleScript(script)
    }

    private func runAppleScript(_ script: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        do {
            try task.run()
        } catch {
            print("❌ Script Error: \(error)")
        }
    }
}
