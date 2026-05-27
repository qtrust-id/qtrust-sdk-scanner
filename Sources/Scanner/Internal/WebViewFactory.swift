#if os(iOS)
import WebKit

enum WebViewFactory {
    static func create(frame: CGRect, bridge: ScannerBridge) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(bridge, name: "scannerBridge")
        config.userContentController = contentController

        let webView = WKWebView(frame: frame, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false

        return webView
    }
}
#endif
