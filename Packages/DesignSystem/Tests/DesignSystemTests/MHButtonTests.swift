import XCTest
import SwiftUI
@testable import DesignSystem

final class MHButtonTests: XCTestCase {
    // 사이즈별 높이·패딩·radius·gap 이 Figma 실측값과 일치.
    func testMetricsMatchFigma() {
        let l = MHButtonSize.large.metric
        XCTAssertEqual(l.height, 48); XCTAssertEqual(l.hPadding, 28)
        XCTAssertEqual(l.cornerRadius, 12); XCTAssertEqual(l.gap, 6)

        let m = MHButtonSize.medium.metric
        XCTAssertEqual(m.height, 40); XCTAssertEqual(m.hPadding, 20)
        XCTAssertEqual(m.cornerRadius, 10); XCTAssertEqual(m.gap, 5)

        let s = MHButtonSize.small.metric
        XCTAssertEqual(s.height, 32); XCTAssertEqual(s.hPadding, 14)
        XCTAssertEqual(s.cornerRadius, 8); XCTAssertEqual(s.gap, 4)
    }

    // 실제 렌더 높이가 Figma 고정 높이(48/40/32)와 일치하고, icon-only 는 정사각.
    @MainActor
    func testRenderedHeightsMatchFigma() {
        MHFontRegistrar.registerIfNeeded()
        func rendered<V: View>(_ v: V) -> CGSize {
            let r = ImageRenderer(content: v); r.scale = 1
            return r.uiImage?.size ?? .zero
        }
        XCTAssertEqual(rendered(MHButton("텍스트") {}).height, 48, accuracy: 0.5)
        XCTAssertEqual(rendered(MHButton("텍스트", size: .medium) {}).height, 40, accuracy: 0.5)
        XCTAssertEqual(rendered(MHButton("텍스트", size: .small) {}).height, 32, accuracy: 0.5)

        let iconLarge = rendered(MHButton(icon: .setting) {})
        XCTAssertEqual(iconLarge.height, 48, accuracy: 0.5)
        XCTAssertEqual(iconLarge.width, iconLarge.height, accuracy: 0.5)   // 정사각
    }

    // 아이콘 크기: icon-only 는 정사각 고정(24/20/18), 인라인은 텍스트 라인높이 세로 Fill(20/18/16).
    func testIconSizesMatchFigma() {
        XCTAssertEqual(MHButtonSize.large.metric.iconOnlySize, 24)
        XCTAssertEqual(MHButtonSize.medium.metric.iconOnlySize, 20)
        XCTAssertEqual(MHButtonSize.small.metric.iconOnlySize, 18)

        // 인라인 = typo.lineHeight 반올림 − 2*inset (content 의 계산 공식과 동일)
        func inline(_ size: MHButtonSize) -> CGFloat {
            size.typography(for: .primary).lineHeight.rounded() - size.metric.inlineIconInset * 2
        }
        XCTAssertEqual(inline(.large), 20)
        XCTAssertEqual(inline(.medium), 18)
        XCTAssertEqual(inline(.small), 16)
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
