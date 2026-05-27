import Foundation

#if os(iOS)
public final class Scanner: @unchecked Sendable {
    private let config: ScannerConfig
    private var bridge: ScannerBridge?
    private var timeoutTask: Task<Void, Never>?

    public init(config: ScannerConfig) { self.config = config }

    // Style 1: Closure
    public func start(
        in view: ScannerView, type: ScanType,
        onResult: @escaping (ScanResult) -> Void,
        onError: @escaping (ScannerError) -> Void
    ) {
        let bridge = ScannerBridge()
        bridge.onResult = onResult
        bridge.onError = onError
        self.bridge = bridge
        view.load(config: config, scanType: type, bridge: bridge)
        startTimeout(onError: onError, view: view)
    }

    public func stop(view: ScannerView) {
        timeoutTask?.cancel()
        timeoutTask = nil
        view.tearDown()
        bridge = nil
    }

    // Style 2: AsyncStream
    public func stream(in view: ScannerView, type: ScanType) -> AsyncStream<ScanResult> {
        AsyncStream { continuation in
            let bridge = ScannerBridge()
            bridge.onResult = { result in continuation.yield(result) }
            bridge.onError = { _ in continuation.finish() }
            self.bridge = bridge
            continuation.onTermination = { @Sendable _ in
                DispatchQueue.main.async { view.tearDown() }
            }
            view.load(config: config, scanType: type, bridge: bridge)
        }
    }

    // Style 3: async/await
    public func scan(in view: ScannerView, type: ScanType) async throws -> ScanResult {
        try await withCheckedThrowingContinuation { continuation in
            let bridge = ScannerBridge()
            var resumed = false

            bridge.onResult = { [weak self] result in
                guard !resumed else { return }
                resumed = true
                self?.stop(view: view)
                continuation.resume(returning: result)
            }
            bridge.onError = { error in
                guard !resumed else { return }
                resumed = true
                view.tearDown()
                continuation.resume(throwing: error)
            }
            self.bridge = bridge
            view.load(config: config, scanType: type, bridge: bridge)

            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.config.timeout ?? 30) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { view.tearDown() }
                continuation.resume(throwing: ScannerError.timeout("scan timed out after \(self?.config.timeout ?? 30)s"))
            }
        }
    }

    private func startTimeout(onError: @escaping (ScannerError) -> Void, view: ScannerView) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.config.timeout ?? 30) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onError(.timeout("scan timed out after \(self?.config.timeout ?? 30)s"))
                view.tearDown()
            }
        }
    }
}
#else
// Stub for non-iOS platforms
public final class Scanner: @unchecked Sendable {
    public init(config: ScannerConfig) {}
}
#endif
