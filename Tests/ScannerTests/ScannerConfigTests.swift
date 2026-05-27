import XCTest
@testable import QTrustScanner

final class ScannerConfigTests: XCTestCase {
    func testDefaults() {
        let config = ScannerConfig(apiKey: "sk_live_test")
        XCTAssertEqual(config.apiKey, "sk_live_test")
        XCTAssertEqual(config.baseUrl, "https://scan.qtrust.id")
        XCTAssertEqual(config.timeout, 30)
    }

    func testCustomValues() {
        let config = ScannerConfig(apiKey: "sk_live_test", baseUrl: "https://custom.host", timeout: 60)
        XCTAssertEqual(config.baseUrl, "https://custom.host")
        XCTAssertEqual(config.timeout, 60)
    }
}
