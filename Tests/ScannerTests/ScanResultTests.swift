import XCTest
@testable import QTrustScanner

final class ScanResultTests: XCTestCase {
    func testDecodeFromJSON() throws {
        let json = """
        {
            "data": "https://example.com",
            "format": "QR_CODE",
            "confidence": 0.98,
            "bounding_box": { "x": 120, "y": 80, "width": 200, "height": 200 }
        }
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(ScanResult.self, from: json)
        XCTAssertEqual(result.data, "https://example.com")
        XCTAssertEqual(result.format, "QR_CODE")
        XCTAssertEqual(result.confidence, 0.98, accuracy: 0.001)
        XCTAssertEqual(result.boundingBox.x, 120)
        XCTAssertEqual(result.boundingBox.y, 80)
        XCTAssertEqual(result.boundingBox.width, 200)
        XCTAssertEqual(result.boundingBox.height, 200)
    }

    func testDecodeInvalidJSON() {
        let json = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ScanResult.self, from: json))
    }
}
