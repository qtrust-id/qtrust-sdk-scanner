import Foundation

#if os(iOS)
import WebKit
import os.log

private let logger = Logger(subsystem: "id.qtrust.scanner", category: "ScannerBridge")

/// Bridge between the embedded WKWebView and the native scanner API.
///
/// All callbacks (`onResult`, `onError`, `onReady`, `onClose`) are guaranteed
/// to be invoked on the main actor — WKScriptMessageHandler delivers messages on
/// the main thread and every dispatch below hops to main explicitly.
@MainActor
final class ScannerBridge: NSObject, WKScriptMessageHandler {
    var onResult: ((ScanResult) -> Void)?
    var onError: ((ScannerError) -> Void)?
    var onReady: (() -> Void)?
    var onClose: (() -> Void)?

    private let decoder = JSONDecoder()

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        let capturedBody = body
        Task { @MainActor in
            self.handle(type: type, body: capturedBody)
        }
    }

    private func handle(type: String, body: [String: Any]) {
        switch type {
        case "result":
            handleResult(body["data"])
        case "error":
            let msg = body["message"] as? String ?? "unknown error"
            logger.error("Bridge error: \(msg)")
            onError?(.serverError(msg))
        case "ready":
            logger.info("Bridge: ready")
            onReady?()
        case "close":
            logger.info("Bridge: close")
            onClose?()
        case "console":
            let level = body["level"] as? String ?? "log"
            let msg = body["message"] as? String ?? ""
            switch level {
            case "error":
                logger.error("[JS] \(msg)")
            case "warn":
                logger.warning("[JS] \(msg)")
            case "debug":
                logger.debug("[JS] \(msg)")
            default:
                logger.info("[JS] \(msg)")
            }
        default:
            break
        }
    }

    private func handleResult(_ data: Any?) {
        guard let dict = data,
              let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let result = try? decoder.decode(ScanResult.self, from: jsonData) else {
            onError?(.serverError("failed to parse result"))
            return
        }
        logger.info("Bridge result: \(result.data)")
        onResult?(result)
    }
}
#else
final class ScannerBridge {
    var onResult: ((ScanResult) -> Void)?
    var onError: ((ScannerError) -> Void)?
    var onReady: (() -> Void)?
    var onClose: (() -> Void)?
}
#endif
