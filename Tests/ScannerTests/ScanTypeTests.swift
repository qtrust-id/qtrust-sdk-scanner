import XCTest
@testable import QTrustScanner

final class ScanTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(ScanType.qr.rawValue, "qr")
        XCTAssertEqual(ScanType.barcode.rawValue, "barcode")
    }
}
