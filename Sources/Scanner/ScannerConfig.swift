import Foundation

public struct ScannerConfig: Sendable {
    public let apiKey: String
    public let baseUrl: String
    public let timeout: TimeInterval

    public init(
        apiKey: String,
        baseUrl: String = "https://scan.qtrust.id",
        timeout: TimeInterval = 30
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.timeout = timeout
    }
}
