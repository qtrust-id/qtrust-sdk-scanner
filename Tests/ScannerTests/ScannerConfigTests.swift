import XCTest
@testable import QTrustScanner

final class ScannerConfigTests: XCTestCase {
    func testDefaults() {
        let config = ScannerConfig()
        XCTAssertEqual(config.timeout, 30)
        XCTAssertEqual(config.vendorConfig.vendorId, "")
        XCTAssertEqual(config.vendorConfig.textHintScan, "")
        XCTAssertEqual(config.vendorConfig.theme, .dark)
        XCTAssertEqual(config.vendorConfig.locale, .id)
        XCTAssertTrue(config.vendorConfig.skipTutorial)
    }

    func testCustomValues() {
        let vc = VendorConfig(
            vendorId: "vendor_ahm",
            textHintScan: "Scan QR",
            theme: .light,
            locale: .en,
            skipTutorial: false
        )
        let config = ScannerConfig(
            timeout: 60,
            vendorConfig: vc
        )
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.vendorConfig.vendorId, "vendor_ahm")
        XCTAssertEqual(config.vendorConfig.textHintScan, "Scan QR")
        XCTAssertEqual(config.vendorConfig.theme, .light)
        XCTAssertEqual(config.vendorConfig.locale, .en)
        XCTAssertFalse(config.vendorConfig.skipTutorial)
    }

    func testVendorConfigDefaults() {
        let vc = VendorConfig()
        XCTAssertEqual(vc.vendorId, "")
        XCTAssertEqual(vc.textHintScan, "")
        XCTAssertEqual(vc.theme, .dark)
        XCTAssertEqual(vc.locale, .id)
        XCTAssertTrue(vc.skipTutorial)
    }

    func testThemeRawValues() {
        XCTAssertEqual(ScannerTheme.dark.rawValue, 0)
        XCTAssertEqual(ScannerTheme.light.rawValue, 1)
    }

    func testLocaleRawValues() {
        XCTAssertEqual(ScannerLocale.id.rawValue, 0)
        XCTAssertEqual(ScannerLocale.en.rawValue, 1)
    }
}
