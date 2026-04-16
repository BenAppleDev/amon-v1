import SwiftUI
import WebKit

struct ProtectedSessionSnapshotView: UIViewRepresentable {
    let svgDocument: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: transparent;
            }
            svg {
              display: block;
              width: 100%;
              height: auto;
            }
          </style>
        </head>
        <body>\(svgDocument)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
