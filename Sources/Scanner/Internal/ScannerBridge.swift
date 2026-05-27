import Foundation

#if os(iOS)
import WebKit

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
            DispatchQueue.main.async { [weak self] in
                self?.onError?(.serverError(msg))
            }
        case "ready":
            DispatchQueue.main.async { [weak self] in
                self?.onReady?()
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
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
        }
    }
}
#else
// Stub for non-iOS platforms
final class ScannerBridge: @unchecked Sendable {
    var onResult: ((ScanResult) -> Void)?
    var onError: ((ScannerError) -> Void)?
    var onReady: (() -> Void)?
}
#endif
