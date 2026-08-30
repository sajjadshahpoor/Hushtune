import SwiftUI

struct BrowserView: View {
    @StateObject private var store = BrowserWebViewStore()
    @State private var addressText = ""
    @State private var isEditingAddress = false
    @State private var showManualDownloadSheet = false
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 0) {
            addressBar

            ZStack(alignment: .top) {
                BrowserWebView(store: store)

                if store.isLoading {
                    ProgressView(value: store.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.red)
                }
            }
            .overlay(alignment: .bottom) {
                if !store.detectedVideoURLs.isEmpty {
                    detectedVideoBanner
                }
            }
        }
        .onAppear {
            if store.currentURL == nil {
                navigate(to: "https://www.google.com")
            }
        }
        .sheet(isPresented: $showManualDownloadSheet) {
            ManualDownloadSheet()
        }
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Button { store.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!store.canGoBack)
            Button { store.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!store.canGoForward)

            TextField("Search or enter website", text: $addressText, onEditingChanged: { editing in
                isEditingAddress = editing
            }, onCommit: {
                navigate(to: addressText)
            })
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .submitLabel(.go)
            .onChange(of: store.currentURL) { url in
                if !isEditingAddress {
                    addressText = url?.absoluteString ?? ""
                }
            }

            if store.isLoading {
                Button { store.stopLoading() } label: { Image(systemName: "xmark") }
            } else {
                Button { store.reload() } label: { Image(systemName: "arrow.clockwise") }
            }

            Menu {
                Button {
                    showManualDownloadSheet = true
                } label: {
                    Label("Download video from URL", systemImage: "arrow.down.circle")
                }
                Toggle(isOn: $store.adBlockEnabled) {
                    Label("Block ads & trackers", systemImage: "shield")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var detectedVideoBanner: some View {
        HStack {
            Image(systemName: "video.fill")
            Text("\(store.detectedVideoURLs.count) video\(store.detectedVideoURLs.count > 1 ? "s" : "") found on this page")
                .font(.footnote)
                .lineLimit(1)
            Spacer()
            Button("Download") {
                for url in store.detectedVideoURLs {
                    downloadManager.startDownload(url: url)
                }
                store.clearDetectedVideos()
            }
            .font(.footnote.bold())
        }
        .padding(10)
        .background(.black.opacity(0.75))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private func navigate(to text: String) {
        isEditingAddress = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = URL(string: trimmed), url.scheme != nil {
            store.load(url: url)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            if let url = URL(string: "https://\(trimmed)") {
                store.load(url: url)
            }
        } else if let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://www.google.com/search?q=\(query)") {
            store.load(url: url)
        }
    }
}
