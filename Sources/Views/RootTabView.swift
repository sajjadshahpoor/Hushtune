import SwiftUI

struct RootTabView: View {
    var body: some View {
        if Config.isAPIKeyConfigured {
            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

                NavigationStack {
                    SearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            .tint(.red)
        } else {
            MissingAPIKeyView()
        }
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
