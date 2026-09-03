import XCTest
import UIKit
@testable import DesignSystem

final class MHTypographyTests: XCTestCase {
    // 번들된 SUITE OTF가 런타임에 등록돼 PostScript 이름으로 로드되는지.
    func testSuiteFontsRegisterAndResolve() {
        MHFontRegistrar.registerIfNeeded()
        for name in ["SUITE-Regular", "SUITE-Medium", "SUITE-Bold"] {
            XCTAssertNotNil(
                UIFont(name: name, size: 16),
                "SUITE 폰트 미등록/이름 불일치: \(name)"
            )
        }
    }

    // 자간 = size * percent / 100 (Figma letterSpacing 퍼센트 규칙). 버튼이 쓰는 Body1 Bold 검증.
    func testTrackingMatchesFigmaPercentRule() {
        XCTAssertEqual(MHTypography.body1NormalBold.tracking, 16 * 0.57 / 100, accuracy: 0.0001)
        XCTAssertEqual(MHTypography.display1Bold.tracking, 56 * -3.19 / 100, accuracy: 0.0001)
    }

    // 목표 줄높이 = size * lineHeightMultiple.
    func testLineHeightMultiple() {
        XCTAssertEqual(MHTypography.body1NormalRegular.lineHeight, 16 * 1.5, accuracy: 0.0001)
        XCTAssertEqual(MHTypography.title1Bold.lineHeight, 32 * 1.375, accuracy: 0.0001)
    }

    // 버튼(A)이 참조하는 텍스트 스타일이 존재하고 크기/굵기가 맞는지.
    func testButtonTextStylesExist() {
        XCTAssertEqual(MHTypography.body1NormalBold.size, 16)   // Large
        XCTAssertEqual(MHTypography.body2NormalBold.size, 15)   // Medium
        XCTAssertEqual(MHTypography.label2Bold.size, 13)        // Small
        XCTAssertEqual(MHTypography.body1NormalBold.weight, .bold)
    }
}
