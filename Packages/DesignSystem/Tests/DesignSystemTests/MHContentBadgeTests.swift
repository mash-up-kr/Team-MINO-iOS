import XCTest
import SwiftUI
@testable import DesignSystem

final class MHContentBadgeTests: XCTestCase {
    // 사이즈별 높이·패딩·radius·폰트·아이콘·gap 이 Figma 실측값과 일치.
    func testMetricsMatchFigma() {
        let xs = MHContentBadgeSize.xsmall.metric
        XCTAssertEqual(xs.height, 20); XCTAssertEqual(xs.hPadding, 6); XCTAssertEqual(xs.cornerRadius, 6)
        XCTAssertEqual(xs.gap, 2); XCTAssertEqual(xs.iconSize, 12); XCTAssertEqual(xs.font, .caption2Medium)

        let s = MHContentBadgeSize.small.metric
        XCTAssertEqual(s.height, 24); XCTAssertEqual(s.hPadding, 6); XCTAssertEqual(s.cornerRadius, 6)
        XCTAssertEqual(s.gap, 3); XCTAssertEqual(s.iconSize, 14); XCTAssertEqual(s.font, .caption1Medium)

        let m = MHContentBadgeSize.medium.metric
        XCTAssertEqual(m.height, 28); XCTAssertEqual(m.hPadding, 8); XCTAssertEqual(m.cornerRadius, 8)
        XCTAssertEqual(m.gap, 4); XCTAssertEqual(m.iconSize, 16); XCTAssertEqual(m.font, .label2Medium)
    }

    // Neutral(color=nil): 글자=Label/Alternative, Solid 배경=Fill/Normal, Outlined 테두리=Line/Normal/Neutral.
    func testNeutralColors() {
        let solid = MHContentBadgeSpec(variant: .solid, color: nil)
        XCTAssertEqual(solid.contentColor, .mhLabelAlternative)
        XCTAssertEqual(solid.fillColor, .mhFillNormal)
        XCTAssertNil(solid.borderColor)

        let outlined = MHContentBadgeSpec(variant: .outlined, color: nil)
        XCTAssertEqual(outlined.contentColor, .mhLabelAlternative)
        XCTAssertEqual(outlined.fillColor, .clear)
        XCTAssertEqual(outlined.borderColor, .mhLineNormalNeutral)
    }

    // Accent(color=강조색): 글자=그 색, Solid 배경=그 색 8%, Outlined 테두리=그 색 43%.
    func testAccentColors() {
        let c = Color.mhAccentForegroundCyan
        let solid = MHContentBadgeSpec(variant: .solid, color: c)
        XCTAssertEqual(solid.contentColor, c)
        XCTAssertEqual(solid.fillColor, c.opacity(0.08))
        XCTAssertNil(solid.borderColor)

        let outlined = MHContentBadgeSpec(variant: .outlined, color: c)
        XCTAssertEqual(outlined.contentColor, c)
        XCTAssertEqual(outlined.fillColor, .clear)
        XCTAssertEqual(outlined.borderColor, c.opacity(0.43))
    }

    // 실제 렌더 높이가 Figma 고정 높이(20/24/28)와 일치.
    @MainActor
    func testRenderedHeights() {
        MHFontRegistrar.registerIfNeeded()
        func h(_ size: MHContentBadgeSize) -> CGFloat {
            let r = ImageRenderer(content: MHContentBadge("텍스트", size: size)); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }
        XCTAssertEqual(h(.xsmall), 20, accuracy: 0.5)
        XCTAssertEqual(h(.small), 24, accuracy: 0.5)
        XCTAssertEqual(h(.medium), 28, accuracy: 0.5)
    }
}
