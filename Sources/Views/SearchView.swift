import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView()
            } else if let errorMessage {
                ErrorStateView(message: errorMessage)
            } else if videos.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("No results")
                    .foregroundStyle(.secondary)
            } else {
                List(videos) { video in
                    NavigationLink(value: video) {
                        VideoRowView(video: video)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: YouTubeVideo.self) { video in
            PlayerView(video: video)
        }
        .searchable(text: $query, prompt: "Search Hushtune")
        .onChange(of: query) { newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                videos = []
                errorMessage = nil
                return
            }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await performSearch(query: trimmed)
            }
        }
    }

    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await YouTubeAPIService.shared.search(query: query)
            videos = result.videos
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
