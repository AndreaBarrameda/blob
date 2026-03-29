import Foundation
import AppKit

class SpotifyWebAPI {
    func searchAndPlay(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "spotify:search:\(encodedQuery)") else { return }

        NSWorkspace.shared.open(url)

        // Give Spotify time to load the search results, then trigger play on the first result
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            self.runAppleScript("""
            tell application "Spotify" to activate
            delay 0.3
            tell application "System Events"
                tell process "Spotify"
                    key code 36
                end tell
            end tell
            """)
        }
    }

    private func runAppleScript(_ script: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }
}
