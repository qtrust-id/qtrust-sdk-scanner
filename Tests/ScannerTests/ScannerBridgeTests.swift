#if os(iOS)
import Testing
import WebKit
@testable import QTrustScanner

// MARK: - Helpers

/// Minimal WKScriptMessage stand-in that lets us inject arbitrary body values
/// without a live WKWebView.
private final class StubScriptMessage: WKScriptMessage {
    private let _body: Any
    override var body: Any { _body }
    init(body: Any) { _body = body }
}

/// Drive the bridge via its public WKScriptMessageHandler entry-point so the
/// full dispatch path (nonisolated → Task @MainActor → handle) is exercised.
@MainActor
private func send(bridge: ScannerBridge, body: Any) async {
    // WKUserContentController is never actually used — the bridge only reads
    // message.body, so we pass a plain instance.
    let controller = WKUserContentController()
    let message = StubScriptMessage(body: body)
    bridge.userContentController(controller, didReceive: message)
    // Yield to let the Task{ @MainActor } posted inside the handler complete.
    await Task.yield()
    await Task.yield()
}

// MARK: - Tests

@MainActor
@Suite("ScannerBridge message dispatch")
struct ScannerBridgeTests {

    // MARK: result

    @Test("result message with valid data calls onResult")
    func resultDispatchesOnResult() async {
        let bridge = ScannerBridge()
        var received: ScanResult?
        bridge.onResult = { received = $0 }

        let body: [String: Any] = [
            "type": "result",
            "data": [
                "data": "https://example.com",
                "format": "QR_CODE",
                "bounding_box": ["x": 10, "y": 20, "width": 100, "height": 80],
            ] as [String: Any],
        ]
        await send(bridge: bridge, body: body)

        #expect(received?.data == "https://example.com")
        #expect(received?.format == "QR_CODE")
        #expect(received?.boundingBox.x == 10)
    }

    @Test("result message with missing bounding_box calls onError")
    func malformedResultCallsOnError() async {
        let bridge = ScannerBridge()
        var errorReceived: ScannerError?
        bridge.onError = { errorReceived = $0 }

        // bounding_box is absent — Decodable will fail
        let body: [String: Any] = [
            "type": "result",
            "data": ["data": "x", "format": "QR_CODE"] as [String: Any],
        ]
        await send(bridge: bridge, body: body)

        #expect(errorReceived != nil)
    }

    @Test("result message with nil data calls onError")
    func nilDataCallsOnError() async {
        let bridge = ScannerBridge()
        var errorReceived: ScannerError?
        bridge.onError = { errorReceived = $0 }

        let body: [String: Any] = ["type": "result"]   // no "data" key
        await send(bridge: bridge, body: body)

        #expect(errorReceived != nil)
    }

    // MARK: error

    @Test("error message with message string calls onError(.serverError)")
    func errorDispatchesOnError() async {
        let bridge = ScannerBridge()
        var errorReceived: ScannerError?
        bridge.onError = { errorReceived = $0 }

        let body: [String: Any] = ["type": "error", "message": "camera unavailable"]
        await send(bridge: bridge, body: body)

        if case .serverError(let msg) = errorReceived {
            #expect(msg == "camera unavailable")
        } else {
            Issue.record("Expected .serverError, got \(String(describing: errorReceived))")
        }
    }

    @Test("error message without message key falls back to 'unknown error'")
    func errorFallsBackToUnknownError() async {
        let bridge = ScannerBridge()
        var errorReceived: ScannerError?
        bridge.onError = { errorReceived = $0 }

        let body: [String: Any] = ["type": "error"]
        await send(bridge: bridge, body: body)

        if case .serverError(let msg) = errorReceived {
            #expect(msg == "unknown error")
        } else {
            Issue.record("Expected .serverError")
        }
    }

    // MARK: ready

    @Test("ready message calls onReady")
    func readyDispatchesOnReady() async {
        let bridge = ScannerBridge()
        var readyCalled = false
        bridge.onReady = { readyCalled = true }

        await send(bridge: bridge, body: ["type": "ready"])

        #expect(readyCalled)
    }

    // MARK: close

    @Test("close message calls onClose")
    func closeDispatchesOnClose() async {
        let bridge = ScannerBridge()
        var closeCalled = false
        bridge.onClose = { closeCalled = true }

        await send(bridge: bridge, body: ["type": "close"])

        #expect(closeCalled)
    }

    // MARK: unknown / malformed

    @Test("unknown type is silently ignored")
    func unknownTypeIgnored() async {
        let bridge = ScannerBridge()
        var anyCalled = false
        bridge.onResult = { _ in anyCalled = true }
        bridge.onError = { _ in anyCalled = true }
        bridge.onReady = { anyCalled = true }
        bridge.onClose = { anyCalled = true }

        await send(bridge: bridge, body: ["type": "unsupported_future_event"])

        #expect(!anyCalled)
    }

    @Test("non-dictionary body is silently ignored — no crash")
    func nonDictionaryBodyIgnored() async {
        let bridge = ScannerBridge()
        var anyCalled = false
        bridge.onError = { _ in anyCalled = true }

        // body is a plain string — guard let body = message.body as? [String: Any] fails
        await send(bridge: bridge, body: "not a dictionary")

        #expect(!anyCalled)
    }

    @Test("body missing type key is silently ignored — no crash")
    func missingTypeKeyIgnored() async {
        let bridge = ScannerBridge()
        var anyCalled = false
        bridge.onError = { _ in anyCalled = true }

        await send(bridge: bridge, body: ["message": "oops"])

        #expect(!anyCalled)
    }

    // MARK: tearDown idempotency

    @Test("callbacks set to nil after tearDown do not crash on late message delivery")
    func nilCallbacksAfterTearDownDoNotCrash() async {
        let bridge = ScannerBridge()
        // Assign then nil all callbacks — simulates tearDown clearing state
        bridge.onResult = { _ in }
        bridge.onError = { _ in }
        bridge.onReady = {}
        bridge.onClose = {}
        bridge.onResult = nil
        bridge.onError = nil
        bridge.onReady = nil
        bridge.onClose = nil

        // Late delivery of every message type must not crash
        for type_ in ["result", "error", "ready", "close"] {
            await send(bridge: bridge, body: ["type": type_])
        }
        // Reaching here means no crash occurred
        #expect(Bool(true))
    }
}
#endif
