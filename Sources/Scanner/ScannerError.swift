import Foundation

public enum ScannerError: LocalizedError, Sendable {
    case connectionFailed(String)
    case permissionDenied(String)
    case timeout(String)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg),
             .permissionDenied(let msg),
             .timeout(let msg),
             .serverError(let msg):
            return msg
        }
    }
}
