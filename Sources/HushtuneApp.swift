import SwiftUI

@main
struct HushtuneApp: App {
    init() {
        AudioSessionManager.configureForBackgroundPlayback()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
