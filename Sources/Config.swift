import Foundation

enum Config {
    /// Paste your YouTube Data API v3 key here.
    /// See README.md for how to create one (Google Cloud Console -> APIs & Services).
    static let youTubeAPIKey = "YOUR_YOUTUBE_API_KEY_HERE"

    static var isAPIKeyConfigured: Bool {
        youTubeAPIKey != "YOUR_YOUTUBE_API_KEY_HERE" && !youTubeAPIKey.isEmpty
    }
}
