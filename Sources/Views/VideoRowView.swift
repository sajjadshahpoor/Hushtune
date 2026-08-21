import SwiftUI

struct VideoRowView: View {
    let video: YouTubeVideo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: video.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(.gray.opacity(0.2))
                    }
                }
                .frame(width: 160, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let duration = video.durationText, !duration.isEmpty {
                    Text(duration)
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(video.channelTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let viewCount = video.viewCountText {
                    Text(viewCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
