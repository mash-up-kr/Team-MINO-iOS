import XCTest
@testable import Core

final class StringExtensionsTests: XCTestCase {
    func test_trimmed_removesSurroundingWhitespaceAndNewlines() {
        XCTAssertEqual("  hello \n".trimmed, "hello")
    }

    func test_nilIfEmpty_returnsNilForBlankString() {
        XCTAssertNil("   ".nilIfEmpty)
    }

    func test_nilIfEmpty_returnsOriginalForNonBlankString() {
        XCTAssertEqual("a".nilIfEmpty, "a")
    }
}
