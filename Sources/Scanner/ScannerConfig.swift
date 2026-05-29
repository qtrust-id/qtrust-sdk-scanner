import Foundation

/// Theme for the scanner UI.
public enum ScannerTheme: Int, Sendable {
    case dark = 0
    case light = 1
}

/// Display locale for scanner UI text.
public enum ScannerLocale: Int, Sendable {
    case id = 0
    case en = 1
}

/// Vendor-specific configuration passed to the scanner web layer.
public struct VendorConfig: Sendable {
    public let vendorId: String
    public let textHintScan: String
    public let theme: ScannerTheme
    public let locale: ScannerLocale
    public let skipTutorial: Bool
    public let rawResult: Bool

    public init(
        vendorId: String = "",
        textHintScan: String = "",
        theme: ScannerTheme = .dark,
        locale: ScannerLocale = .id,
        skipTutorial: Bool = true,
        rawResult: Bool = false
    ) {
        self.vendorId = vendorId
        self.textHintScan = textHintScan
        self.theme = theme
        self.locale = locale
        self.skipTutorial = skipTutorial
        self.rawResult = rawResult
    }
}

public struct ScannerConfig: Sendable {
    public let apiKey: String
    public let baseUrl: String
    public let timeout: TimeInterval
    public let vendorConfig: VendorConfig

    public init(
        apiKey: String,
        baseUrl: String = "https://scan.qtrust.id",
        timeout: TimeInterval = 30,
        vendorConfig: VendorConfig = VendorConfig()
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.timeout = timeout
        self.vendorConfig = vendorConfig
    }
}
