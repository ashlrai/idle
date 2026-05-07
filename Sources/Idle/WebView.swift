import SwiftUI
import WebKit

/// Reusable WKWebView wrapped for SwiftUI with persistent state per `key`.
/// Cookies and form state survive across mount/unmount because we cache the
/// webview itself, keyed by id, in the shared cache.
struct WebView: NSViewRepresentable {
    let url: URL
    let key: String
    /// Optional JS to run every time a page finishes loading at this URL's host.
    var onLoadJS: String? = nil

    func makeCoordinator() -> Coordinator {
        let coord = Coordinator()
        coord.onLoadJS = onLoadJS
        return coord
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WebViewCache.shared.view(for: key, url: url)
        if view.navigationDelegate == nil {
            view.navigationDelegate = context.coordinator
            WebViewCache.shared.setCoordinator(context.coordinator, for: key)
        }
        context.coordinator.onLoadJS = onLoadJS
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.onLoadJS = onLoadJS
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadJS: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let js = onLoadJS else { return }
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

@MainActor
final class WebViewCache {
    static let shared = WebViewCache()
    private var views: [String: WKWebView] = [:]
    private var coordinators: [String: WebView.Coordinator] = [:]
    private let processPool = WKProcessPool()

    func view(for key: String, url: URL) -> WKWebView {
        if let existing = views[key] { return existing }

        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.websiteDataStore = .default()

        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        views[key] = view
        return view
    }

    func setCoordinator(_ coordinator: WebView.Coordinator, for key: String) {
        coordinators[key] = coordinator
    }

    func runJS(_ js: String, on key: String, completion: ((Any?) -> Void)? = nil) {
        guard let view = views[key] else { completion?(nil); return }
        view.evaluateJavaScript(js) { result, _ in completion?(result) }
    }

    func reload(_ key: String) {
        views[key]?.reload()
    }
}
