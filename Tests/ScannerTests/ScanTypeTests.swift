import XCTest
@testable import QTrustScanner

final class ScanTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(ScanType.qr.rawValue, 0)
        XCTAssertEqual(ScanType.barcode.rawValue, 1)
    }
}
