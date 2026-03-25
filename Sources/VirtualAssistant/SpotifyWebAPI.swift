import Foundation
import AppKit

class SpotifyWebAPI {
    func searchAndPlay(query: String) {
        // Open Spotify search - user can click play from there
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        let spotifySearchURI = "spotify:search:\(encodedQuery)"

        if let url = URL(string: spotifySearchURI) {
            NSWorkspace.shared.open(url)
        }
    }
}
