import SwiftUI
import WebKit

public struct WebViewContainer: UIViewRepresentable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
