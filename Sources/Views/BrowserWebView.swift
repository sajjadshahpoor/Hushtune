import SwiftUI
import WebKit

@MainActor
final class BrowserWebViewStore: NSObject, ObservableObject {
    @Published var currentURL: URL?
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var detectedVideoURLs: [URL] = []
    @Published var adBlockEnabled = true {
        didSet { applyAdBlock() }
    }

    fileprivate weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        applyAdBlock()
    }

    func load(url: URL) {
        detectedVideoURLs = []
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }

    func clearDetectedVideos() {
        detectedVideoURLs = []
    }

    private func applyAdBlock() {
        guard let webView else { return }
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        guard adBlockEnabled else { return }
        AdBlockManager.shared.compiledRuleList { ruleList in
            guard let ruleList else { return }
            controller.add(ruleList)
        }
    }
}

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var store: BrowserWebViewStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "hushtuneVideoDetector")
        config.userContentController.addUserScript(
            WKUserScript(source: Self.videoDetectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.observe(webView)
        store.attach(webView)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static let videoDetectionScript = """
    (function() {
      function collect() {
        var urls = new Set();
        document.querySelectorAll('video').forEach(function(v) {
          var src = v.currentSrc || v.src;
          if (src && src.indexOf('blob:') !== 0 && src.indexOf('data:') !== 0) urls.add(src);
          v.querySelectorAll('source').forEach(function(s) {
            if (s.src && s.src.indexOf('blob:') !== 0 && s.src.indexOf('data:') !== 0) urls.add(s.src);
          });
        });
        var metaVideo = document.querySelector('meta[property="og:video:url"], meta[property="og:video"]');
        if (metaVideo && metaVideo.content) urls.add(metaVideo.content);
        return Array.from(urls);
      }
      function report() {
        var found = collect();
        if (found.length > 0 && window.webkit && window.webkit.messageHandlers.hushtuneVideoDetector) {
          window.webkit.messageHandlers.hushtuneVideoDetector.postMessage(found);
        }
      }
      report();
      var observer = new MutationObserver(report);
      observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });
      document.addEventListener('loadedmetadata', report, true);
    })();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let store: BrowserWebViewStore
        private var progressObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var backObservation: NSKeyValueObservation?
        private var forwardObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?

        init(store: BrowserWebViewStore) {
            self.store = store
        }

        func observe(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak store] webView, _ in
                let value = webView.estimatedProgress
                Task { @MainActor in store?.estimatedProgress = value }
            }
            loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak store] webView, _ in
                let value = webView.isLoading
                Task { @MainActor in store?.isLoading = value }
            }
            backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak store] webView, _ in
                let value = webView.canGoBack
                Task { @MainActor in store?.canGoBack = value }
            }
            forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak store] webView, _ in
                let value = webView.canGoForward
                Task { @MainActor in store?.canGoForward = value }
            }
            urlObservation = webView.observe(\.url, options: [.new]) { [weak store] webView, _ in
                let value = webView.url
                Task { @MainActor in store?.currentURL = value }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor [store] in store.clearDetectedVideos() }
        }

        // Blocks popup windows / pop-unders: instead of opening a new WKWebView
        // for window.open()/target="_blank", load the target in the current view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let strings = message.body as? [String] else { return }
            let urls = strings.compactMap { URL(string: $0) }
            Task { @MainActor [store] in
                var current = store.detectedVideoURLs
                for url in urls where !current.contains(url) {
                    current.append(url)
                }
                store.detectedVideoURLs = current
            }
        }
    }
}
