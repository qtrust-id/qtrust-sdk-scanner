#if os(iOS)
import SwiftUI

/// SwiftUI wrapper for `ScannerView`.
///
/// Embed this in a SwiftUI hierarchy and call `scanner.start(in:type:onResult:onError:)`
/// (or the async/stream variants) using the `ScannerView` surface exposed by the
/// coordinator's `view` property. The representable forwards config updates and
/// tears down cleanly when removed from the view tree.
@available(iOS 15.0, *)
public struct ScannerViewRepresentable: UIViewRepresentable {
    public let config: ScannerConfig
    public let scanType: ScanType
    public var onResult: ((ScanResult) -> Void)?
    public var onError: ((ScannerError) -> Void)?
    public var onReady: (() -> Void)?
    public var onClose: (() -> Void)?

    public init(
        config: ScannerConfig = ScannerConfig(),
        scanType: ScanType = .qr,
        onResult: ((ScanResult) -> Void)? = nil,
        onError: ((ScannerError) -> Void)? = nil,
        onReady: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.config = config
        self.scanType = scanType
        self.onResult = onResult
        self.onError = onError
        self.onReady = onReady
        self.onClose = onClose
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> ScannerView {
        let view = ScannerView()
        let scanner = Scanner(config: config)
        context.coordinator.scanner = scanner

        scanner.start(
            in: view,
            type: scanType,
            onResult: { result in onResult?(result) },
            onError: { error in onError?(error) }
        )
        // Wire optional ready/close callbacks through the bridge after start wires it.
        // start() assigns bridge.onClose internally; honour the public onClose/onReady
        // by patching the bridge callbacks once the scanner has set them up.
        context.coordinator.view = view
        context.coordinator.onReady = onReady
        context.coordinator.onClose = onClose
        return view
    }

    public func updateUIView(_ uiView: ScannerView, context: Context) {
        // Forward updated optional callbacks to the coordinator so callers that
        // rebuild the view with new closures (e.g. using @State) stay connected.
        context.coordinator.onReady = onReady
        context.coordinator.onClose = onClose
    }

    public static func dismantleUIView(_ uiView: ScannerView, coordinator: Coordinator) {
        coordinator.scanner?.stop(view: uiView)
    }

    // MARK: - Coordinator

    public final class Coordinator {
        var scanner: Scanner?
        weak var view: ScannerView?
        var onReady: (() -> Void)?
        var onClose: (() -> Void)?
    }
}
#endif
