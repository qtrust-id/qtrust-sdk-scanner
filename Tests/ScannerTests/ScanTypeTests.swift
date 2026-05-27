import XCTest
@testable import Scanner

final class ScanTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(ScanType.qr.rawValue, "qr")
        XCTAssertEqual(ScanType.barcode.rawValue, "barcode")
    }
}
