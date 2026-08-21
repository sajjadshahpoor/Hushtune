import SwiftUI
import WebKit

@MainActor
final class PlayerController: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    fileprivate weak var webView: WKWebView?

    func play() {
        webView?.evaluateJavaScript("hushtunePlay();")
    }

    func pause() {
        webView?.evaluateJavaScript("hushtunePause();")
    }

    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("hushtuneSeek(\(seconds));")
    }
}

struct YouTubePlayerWebView: UIViewRepresentable {
    let videoId: String
    @ObservedObject var controller: PlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "hushtune")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        controller.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "youtube_player", withExtension: "html"),
           var components = URLComponents(url: htmlURL, resolvingAgainstBaseURL: false) {
            components.queryItems = [URLQueryItem(name: "v", value: videoId)]
            if let url = components.url {
                webView.loadFileURL(url, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: PlayerController

        init(controller: PlayerController) {
            self.controller = controller
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }

            let currentTime = body["currentTime"] as? Double
            let duration = body["duration"] as? Double
            let state = body["state"] as? Int

            Task { @MainActor [controller] in
                switch event {
                case "ready":
                    controller.isReady = true
                    if let duration { controller.duration = duration }
                case "time":
                    if let currentTime { controller.currentTime = currentTime }
                    if let duration { controller.duration = duration }
                case "stateChange":
                    if let state { controller.isPlaying = (state == 1) }
                default:
                    break
                }
            }
        }
    }
}
