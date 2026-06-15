import XCTest
@testable import DesignSystem

final class TitleLabelTests: XCTestCase {
    @MainActor
    func test_titleLabel_appliesDesignTokens() {
        let label = TitleLabel(text: "안녕하세요")

        XCTAssertEqual(label.text, "안녕하세요")
        XCTAssertEqual(label.font, AppTypography.title)
        XCTAssertEqual(label.textColor, AppColors.textPrimary)
    }
}
