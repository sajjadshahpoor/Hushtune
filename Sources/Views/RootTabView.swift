import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                if Config.isAPIKeyConfigured {
                    HomeView()
                } else {
                    MissingAPIKeyView()
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                if Config.isAPIKeyConfigured {
                    SearchView()
                } else {
                    MissingAPIKeyView()
                }
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            BrowserView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }

            NavigationStack {
                DownloadsView()
            }
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle.fill")
            }
        }
        .tint(.red)
    }
}

private struct MissingAPIKeyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("YouTube API Key Missing")
                .font(.title2.bold())
            Text("Add your YouTube Data API v3 key in Sources/Config.swift to enable search and browsing. See README.md for setup steps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
