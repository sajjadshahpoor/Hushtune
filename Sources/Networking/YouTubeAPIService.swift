import Foundation

enum YouTubeAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "YouTube API key is not configured. Add it in Config.swift."
        case .invalidURL:
            return "Could not build request URL."
        case .requestFailed(let code):
            return "YouTube API request failed (status \(code))."
        }
    }
}

actor YouTubeAPIService {
    static let shared = YouTubeAPIService()

    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session = URLSession.shared
    private let dateFormatter = ISO8601DateFormatter()

    func search(query: String, pageToken: String? = nil) async throws -> (videos: [YouTubeVideo], nextPageToken: String?) {
        guard Config.isAPIKeyConfigured else { throw YouTubeAPIError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/search")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: Config.youTubeAPIKey)
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw YouTubeAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(SearchListResponse.self, from: data)
        let videoIDs = decoded.items.compactMap { $0.id.videoId }
        let details = try await fetchDetails(ids: videoIDs)

        let videos = decoded.items.compactMap { item -> YouTubeVideo? in
            guard let videoId = item.id.videoId else { return nil }
            let detail = details[videoId]
            return YouTubeVideo(
                id: videoId,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: item.snippet.thumbnails.bestURL,
                publishedAt: item.snippet.publishedAt.flatMap { dateFormatter.date(from: $0) },
                durationText: detail?.duration,
                viewCountText: detail?.viewCount
            )
        }

        return (videos, decoded.nextPageToken)
    }

    func fetchTrending(regionCode: String = "US") async throws -> [YouTubeVideo] {
        guard Config.isAPIKeyConfigured else { throw YouTubeAPIError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "key", value: Config.youTubeAPIKey)
        ]

        guard let url = components.url else { throw YouTubeAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(VideoListResponse.self, from: data)
        return decoded.items.compactMap { item -> YouTubeVideo? in
            guard let snippet = item.snippet else { return nil }
            return YouTubeVideo(
                id: item.id,
                title: snippet.title,
                channelTitle: snippet.channelTitle,
                thumbnailURL: snippet.thumbnails.bestURL,
                publishedAt: snippet.publishedAt.flatMap { dateFormatter.date(from: $0) },
                durationText: item.contentDetails.map { ISO8601DurationParser.parse($0.duration) },
                viewCountText: ViewCountFormatter.format(item.statistics?.viewCount)
            )
        }
    }

    private func fetchDetails(ids: [String]) async throws -> [String: (duration: String, viewCount: String?)] {
        guard !ids.isEmpty else { return [:] }

        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails,statistics"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "key", value: Config.youTubeAPIKey)
        ]

        guard let url = components.url else { throw YouTubeAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(VideoListResponse.self, from: data)
        var result: [String: (duration: String, viewCount: String?)] = [:]
        for item in decoded.items {
            let duration = item.contentDetails.map { ISO8601DurationParser.parse($0.duration) } ?? ""
            result[item.id] = (duration, ViewCountFormatter.format(item.statistics?.viewCount))
        }
        return result
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw YouTubeAPIError.requestFailed(code)
        }
    }
}
