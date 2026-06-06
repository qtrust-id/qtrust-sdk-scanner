#if os(iOS)
import WebKit

/// Weak proxy for a WKScriptMessageHandler.
///
/// `WKUserContentController.add(_:name:)` retains its handler strongly, and the
/// controller is owned (transitively) by the WKWebView, which is owned by the view
/// that registered it. Registering the bridge directly creates a retain cycle that
/// prevents `deinit` from ever running, leaking the view, the web view, and any
/// associated camera session. Routing through this weak proxy breaks that cycle.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(controller, didReceive: message)
    }
}
#endif
