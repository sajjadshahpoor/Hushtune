import SwiftUI

struct PlayerView: View {
    let video: YouTubeVideo
    @StateObject private var controller = PlayerController()
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color.black
                    YouTubePlayerWebView(videoId: video.id, controller: controller)

                    if !controller.isReady {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    if controller.isReady {
                        playerControls
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.headline)
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let viewCount = video.viewCountText {
                        Text(viewCount)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }

    private var playerControls: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : controller.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...(max(controller.duration, 1)),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubTime = controller.currentTime
                    } else {
                        controller.seek(to: scrubTime)
                        isScrubbing = false
                    }
                }
            )
            .tint(.red)

            HStack {
                Button {
                    if controller.isPlaying {
                        controller.pause()
                    } else {
                        controller.play()
                    }
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Text(timeLabel)
                    .font(.caption.monospacedDigit())

                Spacer()
            }
        }
        .padding(8)
        .background(.black.opacity(0.4))
        .foregroundStyle(.white)
    }

    private var timeLabel: String {
        let current = isScrubbing ? scrubTime : controller.currentTime
        return "\(formatSeconds(current)) / \(formatSeconds(controller.duration))"
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
