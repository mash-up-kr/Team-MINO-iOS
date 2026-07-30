import XCTest
@testable import DesignSystem

final class MHButtonTests: XCTestCase {
    // 사이즈별 패딩·radius·gap 이 Figma 실측값과 일치.
    func testMetricsMatchFigma() {
        let l = MHButtonSize.large.metric
        XCTAssertEqual(l.hPadding, 28); XCTAssertEqual(l.vPadding, 12)
        XCTAssertEqual(l.cornerRadius, 12); XCTAssertEqual(l.gap, 6)

        let m = MHButtonSize.medium.metric
        XCTAssertEqual(m.hPadding, 20); XCTAssertEqual(m.vPadding, 9)
        XCTAssertEqual(m.cornerRadius, 10); XCTAssertEqual(m.gap, 5)

        let s = MHButtonSize.small.metric
        XCTAssertEqual(s.hPadding, 14); XCTAssertEqual(s.vPadding, 7)
        XCTAssertEqual(s.cornerRadius, 8); XCTAssertEqual(s.gap, 4)
    }

    // color 축이 글자 굵기를 가른다: Primary=Bold, Assistive=Medium.
    func testTypographyByColor() {
        XCTAssertEqual(MHButtonSize.large.typography(for: .primary), .body1NormalBold)
        XCTAssertEqual(MHButtonSize.large.typography(for: .assistive), .body1NormalMedium)
        XCTAssertEqual(MHButtonSize.medium.typography(for: .primary), .body2NormalBold)
        XCTAssertEqual(MHButtonSize.medium.typography(for: .assistive), .body2NormalMedium)
        XCTAssertEqual(MHButtonSize.small.typography(for: .primary), .label2Bold)
        XCTAssertEqual(MHButtonSize.small.typography(for: .assistive), .label2Medium)
    }

    // Outlined 만 테두리를 갖고, Solid 는 없다.
    func testBorderOnlyOnOutlined() {
        XCTAssertNil(MHButtonSpec(variant: .solid, color: .primary, size: .large).border)
        XCTAssertNotNil(MHButtonSpec(variant: .outlined, color: .primary, size: .large).border)
        XCTAssertNotNil(MHButtonSpec(variant: .outlined, color: .assistive, size: .medium).border)
    }
}
