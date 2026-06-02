import SwiftUI
import AVFoundation
import WebKit
import QTrustScanner

private typealias QRScanner = QTrustScanner.Scanner

struct ScannerScreen: View {
    let apiKey: String
    let scanType: ScanType
    let skipTutorial: Bool
    let rawResult: Bool
    let apiStyle: ContentView.APIStyle
    let onResult: (ScanResult) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        DirectWebView(
            apiKey: apiKey,
            scanType: scanType,
            skipTutorial: skipTutorial,
            rawResult: rawResult,
            apiStyle: apiStyle,
            onResult: { result in
                onResult(result)
                dismiss()
            },
            onError: { msg in
                errorMessage = msg
                showError = true
            },
            onClose: { dismiss() }
        )
        .ignoresSafeArea(.all)
        .navigationBarHidden(true)
        .alert("Scan Error", isPresented: $showError, actions: {
            Button("OK") { showError = false }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }
}

// MARK: - Full-bleed WKWebView that ignores safe area insets

private final class FullBleedWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets { .zero }
}

// MARK: - Direct WKWebView approach — no SDK wrapper, minimal indirection

private struct DirectWebView: UIViewRepresentable {
    let apiKey: String
    let scanType: ScanType
    let skipTutorial: Bool
    let rawResult: Bool
    let apiStyle: ContentView.APIStyle
    let onResult: (ScanResult) -> Void
    let onError: (String) -> Void
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        // Request native camera permission
        AVCaptureDevice.requestAccess(for: .video) { _ in }

        // Container holds WebView + loading overlay
        let container = UIView()
        container.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "scannerBridge")

        // Inject black background CSS before any content renders
        let blackBg = WKUserScript(
            source: "document.documentElement.style.background='#000';document.body.style.background='#000';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(blackBg)

        // Boot config — a file:// URL cannot reliably carry a query string in
        // WKWebView, so the page reads mode/type from this documentStart global
        // instead of location.search. mode=sdk skips the home screen.
        let bootScript = WKUserScript(
            source: "window.__SCANNER_BOOT__={mode:\"sdk\",type:\(scanType.rawValue)};",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bootScript)
        config.userContentController = contentController

        let wv = FullBleedWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.alpha = 0 // Hidden until ready — prevents white flash
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(wv)

        // Loading overlay with spinner
        let overlay = UIView()
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        overlay.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        container.addSubview(overlay)
        context.coordinator.loadingOverlay = overlay
        context.coordinator.webView = wv
        context.coordinator.container = container

        // Load the offline-capable bundled scanner page from the SDK. file:// is
        // a secure context in WKWebView, so getUserMedia works with no network.
        // The page is a single classic-script bundle (no ES modules, which
        // WKWebView blocks under file://). The cloud serverUrl/API key are injected
        // after load via ScannerInit (see didFinish), keeping the scanner
        // online-primary with an on-device decode fallback when cloud is unreachable.
        if let webDir = ScannerAssets.webDirectoryURL, let indexURL = ScannerAssets.indexURL {
            wv.loadFileURL(indexURL, allowingReadAccessTo: webDir)
            print("[DirectWebView] Loading bundled: \(indexURL.path)")
        } else {
            print("[DirectWebView] bundled scanner assets missing")
            DispatchQueue.main.async {
                self.onError("Bundled scanner assets missing")
            }
        }

        // Timeout fallback — reveal after 15s even if onReady never fires
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak wv] in
            guard context.coordinator.loadingOverlay != nil else { return }
            print("[DirectWebView] Loading timeout — revealing")
            context.coordinator.revealWebView()
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Sync frames on layout changes
        context.coordinator.webView?.frame = uiView.bounds
        context.coordinator.loadingOverlay?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        coordinator.webView?.stopLoading()
        coordinator.loadingOverlay = nil
    }

    // MARK: - Coordinator handles all WK delegates + JS bridge

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: DirectWebView
        weak var webView: WKWebView?
        weak var container: UIView?
        var loadingOverlay: UIView?
        private let decoder = JSONDecoder()

        init(parent: DirectWebView) {
            self.parent = parent
        }

        func revealWebView() {
            guard let overlay = loadingOverlay else { return }
            loadingOverlay = nil
            UIView.animate(withDuration: 0.25) {
                self.webView?.alpha = 1
                overlay.alpha = 0
            } completion: { _ in
                overlay.removeFromSuperview()
            }
        }

        private var receivedHTTPError = false

        // Intercept HTTP response — detect 401 before page finishes
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let http = navigationResponse.response as? HTTPURLResponse, http.statusCode >= 400 {
                print("[DirectWebView] HTTP \(http.statusCode)")
                receivedHTTPError = true
                decisionHandler(.allow) // Let error page render
                let msg = http.statusCode == 401 ? "Invalid or missing API key" : "Server error (HTTP \(http.statusCode))"
                DispatchQueue.main.async {
                    self.revealWebView()
                    self.parent.onError(msg)
                }
                return
            }
            decisionHandler(.allow)
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if receivedHTTPError {
                print("[DirectWebView] didFinish (skipping ScannerInit — HTTP error)")
                return
            }
            print("[DirectWebView] Page loaded, calling ScannerInit")
            let serverUrl = "https://scanner.noersy.my.id"
            let skipTut = parent.skipTutorial ? "true" : "false"
            let rawRes = parent.rawResult ? "true" : "false"
            let js = "window.ScannerInit({key: '\(parent.apiKey)', serverUrl: '\(serverUrl)', type: \(parent.scanType.rawValue), config: {skipTutorial: \(skipTut), rawResult: \(rawRes)}});"
            webView.evaluateJavaScript(js) { _, error in
                if let error {
                    print("[DirectWebView] JS error: \(error)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[DirectWebView] Load failed: \(error)")
            DispatchQueue.main.async { self.parent.onError("Page load failed: \(error.localizedDescription)") }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[DirectWebView] Nav failed: \(error)")
        }

        // WKUIDelegate — auto-grant camera
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            print("[DirectWebView] Camera permission requested — granting")
            decisionHandler(.grant)
        }

        // WKScriptMessageHandler — JS bridge
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "result":
                guard let data = body["data"],
                      let jsonData = try? JSONSerialization.data(withJSONObject: data),
                      let result = try? decoder.decode(ScanResult.self, from: jsonData) else {
                    DispatchQueue.main.async { self.parent.onError("Failed to parse result") }
                    return
                }
                DispatchQueue.main.async { self.parent.onResult(result) }

            case "ready":
                print("[DirectWebView] Scanner ready — revealing")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.revealWebView()
                }

            case "error":
                let msg = body["message"] as? String ?? "unknown"
                print("[DirectWebView] JS error: \(msg)")
                DispatchQueue.main.async {
                    self.revealWebView()
                    self.parent.onError(msg)
                }

            case "close":
                DispatchQueue.main.async { self.parent.onClose() }

            case "console":
                let level = body["level"] as? String ?? "log"
                let msg = body["message"] as? String ?? ""
                print("[DirectWebView] JS \(level): \(msg)")

            default:
                break
            }
        }
    }
}

#Preview {
    ScannerScreen(
        apiKey: "sk_live_test",
        scanType: .qr,
        skipTutorial: true,
        rawResult: false,
        apiStyle: .callback,
        onResult: { _ in }
    )
}
