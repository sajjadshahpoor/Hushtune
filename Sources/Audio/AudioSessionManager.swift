import AVFoundation

enum AudioSessionManager {
    /// Configures the app's audio session so that media playback (from the
    /// browser's web content, or downloaded videos played in-app) continues
    /// when the app is backgrounded or the screen locks. Whether a given page
    /// actually keeps playing also depends on that page's own JavaScript —
    /// sites that pause themselves on visibility change will still do so.
    static func configureForBackgroundPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Hushtune: failed to configure audio session: \(error)")
        }
    }
}
