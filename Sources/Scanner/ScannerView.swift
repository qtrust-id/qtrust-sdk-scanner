#if os(iOS)
import AVFoundation
import UIKit
import WebKit
import os.log

private let logger = Logger(subsystem: "id.qtrust.scanner", category: "ScannerView")

@MainActor
public final class ScannerView: UIView {
    private(set) var webView: WKWebView?
    private var bridge: ScannerBridge?
    private var pageLoadHandler: PageLoadHandler?
    private var cameraDelegate: CameraPermissionDelegate?
    private var pendingLoad: (() -> Void)?
    private var loadingOverlay: UIView?

    private static let loadingDelaySeconds: TimeInterval = 0.5
    private static let loadingTimeoutSec: TimeInterval = 15.0
    private var loadingTimer: DispatchWorkItem?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        webView?.frame = bounds

        if bounds.width > 0, bounds.height > 0, let load = pendingLoad {
            logger.info("layoutSubviews: got real frame \(self.bounds.width)x\(self.bounds.height), executing pending load")
            pendingLoad = nil
            load()
        }
    }

    func load(config: ScannerConfig, scanType: ScanType, bridge: ScannerBridge) {
        logger.info("load() called — bounds: \(self.bounds.width)x\(self.bounds.height)")
        self.bridge = bridge
        webView?.removeFromSuperview()

        // Request native camera permission FIRST, then load web view
        requestCameraPermission { [weak self] granted in
            guard let self else { return }
            if !granted {
                logger.error("Camera permission denied at OS level")
                bridge.onError?(.permissionDenied("Camera permission denied. Enable in Settings."))
                return
            }

            logger.info("Camera permission granted, proceeding to load web view")
            if self.bounds.width == 0 || self.bounds.height == 0 {
                logger.info("load() deferred — zero frame")
                self.pendingLoad = { [weak self] in
                    self?.performLoad(config: config, scanType: scanType, bridge: bridge)
                }
                return
            }
            self.performLoad(config: config, scanType: scanType, bridge: bridge)
        }
    }

    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.info("Camera already authorized")
            completion(true)
        case .notDetermined:
            logger.info("Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    logger.info("Camera permission response: \(granted)")
                    completion(granted)
                }
            }
        case .denied, .restricted:
            logger.error("Camera permission denied/restricted")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func performLoad(config: ScannerConfig, scanType: ScanType, bridge: ScannerBridge) {
        let wv = WebViewFactory.create(frame: bounds, bridge: bridge)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.alpha = 0 // Hidden until ready — prevents white flash
        addSubview(wv)
        self.webView = wv

        // Show loading overlay on top of WebView
        showLoadingOverlay()

        // Reveal WebView + hide loading when scanner is fully ready
        let originalOnReady = bridge.onReady
        bridge.onReady = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadingDelaySeconds) {
                self?.revealWebView()
            }
            originalOnReady?()
        }

        // WKUIDelegate for auto-granting getUserMedia permission
        let camDelegate = CameraPermissionDelegate()
        self.cameraDelegate = camDelegate
        wv.uiDelegate = camDelegate

        // Load the BUNDLED scanner page. file:// in WKWebView is a secure context,
        // so getUserMedia works. Scanning runs fully on-device (zxing-wasm) — no
        // network, no server URL. mode=sdk skips the home screen.
        // Effective bundle = newest verified OTA cache, else the in-SDK seed
        // (resolved once per process by ScannerAssets).
        guard let webDirURL = ScannerAssets.webDirectoryURL else {
            logger.error("performLoad: bundled web resources not found")
            bridge.onError?(.connectionFailed("bundled scanner assets missing"))
            return
        }
        let url = webDirURL.appendingPathComponent("index.html")
        logger.info("performLoad: loading bundled URL \(url.absoluteString)")

        // Boot config — a file:// URL cannot reliably carry a query string
        // (WKWebView fails the navigation), so the page reads mode/type from this
        // documentStart-injected global instead of location.search. mode=sdk skips
        // the home screen.
        let bootJS = "window.__SCANNER_BOOT__={mode:\"sdk\",type:\(scanType.rawValue)};"
        let bootScript = WKUserScript(
            source: bootJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        // Remove any previously injected user scripts before adding the boot script
        // to guarantee exactly one __SCANNER_BOOT__ injection per WKWebView instance.
        wv.configuration.userContentController.removeAllUserScripts()
        wv.configuration.userContentController.addUserScript(bootScript)

        let handler = PageLoadHandler(
            onLoad: { [weak wv, weak bridge] in
                logger.info("PageLoadHandler: page loaded, calling ScannerInit")
                guard let js = Self.buildInitJs(config: config, scanType: scanType) else {
                    logger.error("PageLoadHandler: aborting — ScannerInit payload could not be built")
                    bridge?.onError?(.serverError("failed to build scanner init payload"))
                    return
                }
                wv?.evaluateJavaScript(js) { _, error in
                    if let error {
                        logger.error("JS eval error: \(error.localizedDescription)")
                    } else {
                        logger.info("JS eval success: ScannerInit called")
                    }
                }
            },
            onError: { [weak self, weak bridge] error in
                logger.error("PageLoadHandler: load error — \(error.localizedDescription)")
                self?.revealWebView()
                bridge?.onError?(.connectionFailed("page load failed: \(error.localizedDescription)"))
            }
        )
        self.pageLoadHandler = handler
        wv.navigationDelegate = handler

        wv.loadFileURL(url, allowingReadAccessTo: webDirURL)
        logger.info("performLoad: loadFileURL sent")
    }

    /// Reveals the WebView and fades out the loading overlay simultaneously.
    private func revealWebView() {
        loadingTimer?.cancel()
        loadingTimer = nil
        guard let overlay = loadingOverlay else { return }
        loadingOverlay = nil
        UIView.animate(withDuration: 0.25) {
            self.webView?.alpha = 1
            overlay.alpha = 0
        } completion: { _ in
            overlay.removeFromSuperview()
        }
        logger.info("Revealing WebView, hiding overlay")
    }

    private func showLoadingOverlay() {
        loadingOverlay?.removeFromSuperview()
        let overlay = UIView(frame: bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .black

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        overlay.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        loadingOverlay = overlay
        addSubview(overlay)
        logger.info("Loading overlay shown")

        // Timeout fallback — reveal after max wait even if onReady never fires
        let timeout = DispatchWorkItem { [weak self] in
            guard self?.loadingOverlay != nil else { return }
            logger.warning("Loading overlay timeout — revealing after \(Self.loadingTimeoutSec)s")
            self?.revealWebView()
        }
        loadingTimer = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadingTimeoutSec, execute: timeout)
    }

    /// Build ScannerInit JS call with int enums and vendor config.
    /// The payload is JSON-encoded so every vendor string value (which may come
    /// from a server-side config) is fully escaped — hand-rolled single-quote
    /// escaping could break the literal or inject code.
    ///
    /// Returns `nil` on encode failure; callers should surface that via `bridge.onError`.
    private static func buildInitJs(config: ScannerConfig, scanType: ScanType) -> String? {
        let vc = config.vendorConfig
        let payload: [String: Any] = [
            "type": scanType.rawValue,
            "config": [
                "vendorId": vc.vendorId,
                "textHintScan": vc.textHintScan,
                "theme": vc.theme.rawValue,
                "locale": vc.locale.rawValue,
                "skipTutorial": vc.skipTutorial,
            ] as [String: Any],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            logger.error("buildInitJs: failed to encode payload")
            return nil
        }
        return "window.ScannerInit(\(json));"
    }

    func tearDown() {
        logger.info("tearDown called")
        pendingLoad = nil
        loadingTimer?.cancel()
        loadingTimer = nil
        loadingOverlay?.removeFromSuperview()
        loadingOverlay = nil
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView?.uiDelegate = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        bridge = nil
        pageLoadHandler = nil
        cameraDelegate = nil
    }
}

// MARK: - Navigation delegate

private final class PageLoadHandler: NSObject, WKNavigationDelegate {
    private let onLoad: () -> Void
    private let onError: ((Error) -> Void)?
    private var receivedHTTPError = false

    init(onLoad: @escaping () -> Void, onError: ((Error) -> Void)? = nil) {
        self.onLoad = onLoad
        self.onError = onError
    }

    // Intercept HTTP response — detect 401/4xx/5xx before page finishes loading
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let httpResponse = navigationResponse.response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            logger.error("WKNav: HTTP \(httpResponse.statusCode)")
            receivedHTTPError = true
            let message = "Failed to load scanner (HTTP \(httpResponse.statusCode))"
            // Allow the response so WebView doesn't show blank — error page will render
            decisionHandler(.allow)
            onError?(NSError(
                domain: "ScannerHTTP",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if receivedHTTPError {
            logger.info("WKNav: didFinish (skipping onLoad — HTTP error page)")
            return
        }
        logger.info("WKNav: didFinish")
        onLoad()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WKNav: didFail — \(error.localizedDescription)")
        onError?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WKNav: didFailProvisionalNavigation — \(error.localizedDescription)")
        onError?(error)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logger.info("WKNav: didStartProvisionalNavigation")
    }
}

// MARK: - Auto-grant camera permission for getUserMedia

private final class CameraPermissionDelegate: NSObject, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // Only grant camera access — deny microphone and any future media types.
        let decision: WKPermissionDecision = (type == .camera) ? .grant : .deny
        logger.info("CameraPermission: \(type == .camera ? "granting" : "denying") \(String(describing: type))")
        decisionHandler(decision)
    }
}
#endif
