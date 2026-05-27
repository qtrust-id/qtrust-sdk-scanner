import XCTest
@testable import Scanner

final class ScannerErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let errors: [(ScannerError, String)] = [
            (.connectionFailed("no network"), "no network"),
            (.permissionDenied("camera denied"), "camera denied"),
            (.timeout("30s elapsed"), "30s elapsed"),
            (.serverError("internal error"), "internal error"),
        ]
        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }
}
