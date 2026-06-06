import Foundation

public enum ScannerError: LocalizedError, Sendable {
    case connectionFailed(String)
    case permissionDenied(String)
    case timeout(String)
    case serverError(String)
    /// The user dismissed the scanner before a result was produced.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg),
             .permissionDenied(let msg),
             .timeout(let msg),
             .serverError(let msg):
            return msg
        case .cancelled:
            return "Scanner was cancelled by the user."
        }
    }
}
