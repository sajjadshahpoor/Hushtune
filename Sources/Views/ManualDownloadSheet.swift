import SwiftUI

struct ManualDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @ObservedObject private var downloadManager = DownloadManager.shared

    private var parsedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Video URL") {
                    TextField("https://example.com/video.mp4", text: $urlText)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Text("Works with direct video file links (.mp4, .mov, .m3u8, etc). Pages that stream video through a custom in-page player rather than a direct file link can't be downloaded this way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Download Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        if let url = parsedURL {
                            downloadManager.startDownload(url: url)
                            dismiss()
                        }
                    }
                    .disabled(parsedURL == nil)
                }
            }
        }
    }
}
