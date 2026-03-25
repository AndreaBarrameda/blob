import Foundation
import AppKit

class SpotifyWebAPI {
    func searchAndPlay(query: String) {
        // Open Spotify with search - blob will prompt user to click play
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        let spotifySearchURI = "spotify:search:\(encodedQuery)"

        if let url = URL(string: spotifySearchURI) {
            NSWorkspace.shared.open(url)
        }
    }
}
