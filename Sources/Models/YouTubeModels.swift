import Foundation

struct YouTubeVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?
    var durationText: String?
    var viewCountText: String?
}

// MARK: - search.list response

struct SearchListResponse: Decodable {
    let items: [SearchItem]
    let nextPageToken: String?
}

struct SearchItem: Decodable {
    let id: SearchItemID
    let snippet: Snippet
}

struct SearchItemID: Decodable {
    let videoId: String?
}

struct Snippet: Decodable {
    let title: String
    let channelTitle: String
    let publishedAt: String?
    let thumbnails: Thumbnails
}

struct Thumbnails: Decodable {
    let medium: Thumbnail?
    let high: Thumbnail?
    let `default`: Thumbnail?

    var bestURL: URL? {
        (high ?? medium ?? `default`)?.url.flatMap(URL.init(string:))
    }
}

struct Thumbnail: Decodable {
    let url: String
}

// MARK: - videos.list response (details)

struct VideoListResponse: Decodable {
    let items: [VideoItem]
}

struct VideoItem: Decodable {
    let id: String
    let snippet: Snippet?
    let contentDetails: ContentDetails?
    let statistics: Statistics?
}

struct ContentDetails: Decodable {
    let duration: String
}

struct Statistics: Decodable {
    let viewCount: String?
}
