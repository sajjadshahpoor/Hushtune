import SwiftUI
import AVKit

private struct PlaybackTarget: Identifiable {
    let id = UUID()
    let url: URL
}

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showManualDownloadSheet = false
    @State private var playbackTarget: PlaybackTarget?

    var body: some View {
        List {
            if downloadManager.downloads.isEmpty {
                Text("No downloads yet. Browse to a page with a video, or paste a direct video link.")
                    .foregroundStyle(.secondary)
            }
            ForEach(downloadManager.downloads) { item in
                DownloadRow(item: item) {
                    if let url = item.localFileURL {
                        playbackTarget = PlaybackTarget(url: url)
                    }
                }
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showManualDownloadSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showManualDownloadSheet) {
            ManualDownloadSheet()
        }
        .fullScreenCover(item: $playbackTarget) { target in
            VideoPlayer(player: AVPlayer(url: target.url))
                .ignoresSafeArea()
        }
    }
}

private struct DownloadRow: View {
    let item: DownloadItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.suggestedFileName)
                        .font(.subheadline)
                        .lineLimit(1)
                    switch item.state {
                    case .downloading:
                        ProgressView(value: item.progress)
                    case .completed:
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .failed(let message):
                        Text("Failed: \(message)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .disabled(item.state != .completed)
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch item.state {
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
