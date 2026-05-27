#if os(iOS)
import UIKit
import WebKit

public final class ScannerView: UIView {
    private(set) var webView: WKWebView?
    private var bridge: ScannerBridge?

    func load(config: ScannerConfig, scanType: ScanType, bridge: ScannerBridge) {
        self.bridge = bridge
        webView?.removeFromSuperview()

        let wv = WebViewFactory.create(frame: bounds, bridge: bridge)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(wv)
        self.webView = wv

        let urlString = "\(config.baseUrl)/?type=\(scanType.rawValue)"
        guard let url = URL(string: urlString) else {
            bridge.onError?(.connectionFailed("invalid base URL: \(config.baseUrl)"))
            return
        }

        wv.load(URLRequest(url: url))

        wv.navigationDelegate = PageLoadHandler { [weak wv] in
            let js = "window.ScannerSetAPIKey('\(config.apiKey)');"
            wv?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func tearDown() {
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        bridge = nil
    }
}

private final class PageLoadHandler: NSObject, WKNavigationDelegate {
    private let onLoad: () -> Void
    init(onLoad: @escaping () -> Void) { self.onLoad = onLoad }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onLoad() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
}
#endif
