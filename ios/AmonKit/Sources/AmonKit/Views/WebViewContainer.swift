import SwiftUI
import WebKit

public struct WebViewContainer: UIViewRepresentable {
    private let url: URL
    private let sessionPersistence: BrowsingSessionPersistence

    public init(url: URL, sessionPersistence: BrowsingSessionPersistence = .persistent) {
        self.url = url
        self.sessionPersistence = sessionPersistence
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = BrowserPrivacyController.websiteDataStore(for: sessionPersistence)
        return WKWebView(frame: .zero, configuration: configuration)
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
