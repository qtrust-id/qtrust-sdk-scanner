import Foundation

#if os(iOS)
import WebKit
import os.log

private let logger = Logger(subsystem: "id.qtrust.scanner", category: "ScannerBridge")

final class ScannerBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    var onResult: ((ScanResult) -> Void)?
    var onError: ((ScannerError) -> Void)?
    var onReady: (() -> Void)?

    private let decoder = JSONDecoder()

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "result":
            handleResult(body["data"])
        case "error":
            let msg = body["message"] as? String ?? "unknown error"
            logger.error("Bridge error: \(msg)")
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.serverError(msg))
            }
        case "ready":
            logger.info("Bridge: ready")
            DispatchQueue.main.async { [weak self] in
                self?.onReady?()
            }
        case "console":
            let level = body["level"] as? String ?? "log"
            let msg = body["message"] as? String ?? ""
            switch level {
            case "error":
                logger.error("[JS] \(msg)")
            case "warn":
                logger.warning("[JS] \(msg)")
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
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.serverError("failed to parse result"))
            }
            return
        }
        logger.info("Bridge result: \(result.data)")
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
        }
    }
}
#else
final class ScannerBridge: @unchecked Sendable {
    var onResult: ((ScanResult) -> Void)?
    var onError: ((ScannerError) -> Void)?
    var onReady: (() -> Void)?
}
#endif
