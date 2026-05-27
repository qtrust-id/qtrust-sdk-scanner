#if os(iOS)
import WebKit

enum WebViewFactory {
    static func create(frame: CGRect, bridge: ScannerBridge) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(bridge, name: "scannerBridge")

        // Inject console.log/error/warn capture → native logger
        let consoleCapture = WKUserScript(source: """
            (function() {
                var origLog = console.log;
                var origError = console.error;
                var origWarn = console.warn;
                function send(level, args) {
                    try {
                        var msg = Array.prototype.map.call(args, function(a) {
                            return typeof a === 'object' ? JSON.stringify(a) : String(a);
                        }).join(' ');
                        window.webkit.messageHandlers.scannerBridge.postMessage({
                            type: 'console', level: level, message: msg
                        });
                    } catch(e) {}
                }
                console.log = function() { send('log', arguments); origLog.apply(console, arguments); };
                console.error = function() { send('error', arguments); origError.apply(console, arguments); };
                console.warn = function() { send('warn', arguments); origWarn.apply(console, arguments); };
                window.onerror = function(msg, url, line, col, err) {
                    send('error', ['JS Error: ' + msg + ' at ' + url + ':' + line + ':' + col]);
                };
                window.addEventListener('unhandledrejection', function(e) {
                    send('error', ['Unhandled rejection: ' + (e.reason ? e.reason.message || e.reason : 'unknown')]);
                });
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(consoleCapture)

        // Inject black background CSS before any content renders — prevents white flash
        let blackBg = WKUserScript(
            source: "document.documentElement.style.background='#000';document.body.style.background='#000';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(blackBg)

        config.userContentController = contentController

        let webView = WKWebView(frame: frame, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false

        return webView
    }
}
#endif
