import Foundation

#if os(iOS)
@MainActor
public final class Scanner {
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
        bridge.onClose = { [weak self, weak view] in
            guard let self, let view else { return }
            self.stop(view: view)
        }
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
        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let bridge = ScannerBridge()
            bridge.onResult = { result in continuation.yield(result) }
            bridge.onError = { _ in continuation.finish() }
            bridge.onClose = { continuation.finish() }
            self.bridge = bridge

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in view.tearDown() }
            }

            // Honor config.timeout — finish the stream if it expires
            let timeoutSeconds = self.config.timeout
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    view.tearDown()
                    self?.bridge = nil
                }
                continuation.finish()
            }
            self.timeoutTask = timeoutTask

            view.load(config: config, scanType: type, bridge: bridge)
        }
    }

    // Style 3: async/await
    public func scan(in view: ScannerView, type: ScanType) async throws -> ScanResult {
        return try await withCheckedThrowingContinuation { continuation in
            let bridge = ScannerBridge()
            // `resumed` is checked and mutated exclusively on the main actor (all
            // callbacks run on @MainActor), eliminating the data race.
            var resumed = false

            bridge.onResult = { [weak self] result in
                guard !resumed else { return }
                resumed = true
                self?.stop(view: view)
                continuation.resume(returning: result)
            }
            bridge.onError = { [weak self] error in
                guard !resumed else { return }
                resumed = true
                self?.timeoutTask?.cancel()
                self?.timeoutTask = nil
                view.tearDown()
                self?.bridge = nil
                continuation.resume(throwing: error)
            }
            bridge.onClose = { [weak self] in
                guard !resumed else { return }
                resumed = true
                self?.stop(view: view)
                continuation.resume(throwing: ScannerError.cancelled)
            }
            self.bridge = bridge
            view.load(config: config, scanType: type, bridge: bridge)

            let timeoutSeconds = self.config.timeout
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !resumed else { return }
                    resumed = true
                    view.tearDown()
                    self?.bridge = nil
                    self?.timeoutTask = nil
                    continuation.resume(throwing: ScannerError.timeout("scan timed out after \(timeoutSeconds)s"))
                }
            }
        }
    }

    private func startTimeout(onError: @escaping (ScannerError) -> Void, view: ScannerView) {
        timeoutTask?.cancel()
        let timeoutSeconds = config.timeout
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onError(.timeout("scan timed out after \(timeoutSeconds)s"))
                view.tearDown()
                self?.bridge = nil
            }
        }
    }
}
#else
// Stub for non-iOS platforms
@MainActor
public final class Scanner {
    public init(config: ScannerConfig) {}
}
#endif
