import SwiftUI

struct HomeView: View {
    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView()
            } else if let errorMessage {
                ErrorStateView(message: errorMessage)
            } else {
                List(videos) { video in
                    NavigationLink(value: video) {
                        VideoRowView(video: video)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Hushtune")
        .navigationDestination(for: YouTubeVideo.self) { video in
            PlayerView(video: video)
        }
        .task {
            await loadTrending()
        }
        .refreshable {
            await loadTrending()
        }
    }

    private func loadTrending() async {
        isLoading = true
        errorMessage = nil
        do {
            videos = try await YouTubeAPIService.shared.fetchTrending()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ErrorStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
