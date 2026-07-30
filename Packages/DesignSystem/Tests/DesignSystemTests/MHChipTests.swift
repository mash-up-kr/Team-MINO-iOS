import XCTest
import SwiftUI
@testable import DesignSystem

final class MHChipTests: XCTestCase {
    // 사이즈별 높이·패딩·radius·gap·아이콘이 Figma 실측값과 일치.
    func testMetricsMatchFigma() {
        let xs = MHChipSize.xsmall.metric
        XCTAssertEqual(xs.height, 24); XCTAssertEqual(xs.hPadding, 7)
        XCTAssertEqual(xs.cornerRadius, 6); XCTAssertEqual(xs.gap, 2); XCTAssertEqual(xs.iconSize, 12)

        let s = MHChipSize.small.metric
        XCTAssertEqual(s.height, 32); XCTAssertEqual(s.hPadding, 8)
        XCTAssertEqual(s.cornerRadius, 8); XCTAssertEqual(s.gap, 2); XCTAssertEqual(s.iconSize, 14)

        let m = MHChipSize.medium.metric
        XCTAssertEqual(m.height, 36); XCTAssertEqual(m.hPadding, 11)
        XCTAssertEqual(m.cornerRadius, 10); XCTAssertEqual(m.gap, 3); XCTAssertEqual(m.iconSize, 14)

        let l = MHChipSize.large.metric
        XCTAssertEqual(l.height, 40); XCTAssertEqual(l.hPadding, 12)
        XCTAssertEqual(l.cornerRadius, 10); XCTAssertEqual(l.gap, 3); XCTAssertEqual(l.iconSize, 16)
    }

    // 사이즈별 타이포: XS=Caption1, S=Label1, M·L=Body2 (모두 Medium).
    func testTypographyBySize() {
        XCTAssertEqual(MHChipSize.xsmall.metric.font, .caption1Medium)
        XCTAssertEqual(MHChipSize.small.metric.font, .label1NormalMedium)
        XCTAssertEqual(MHChipSize.medium.metric.font, .body2NormalMedium)
        XCTAssertEqual(MHChipSize.large.metric.font, .body2NormalMedium)
    }

    // 테두리는 Outlined 에만 있고 Solid 엔 없다(활성/비활성/비활성화 무관).
    func testBorderOnlyOnOutlined() {
        func spec(_ v: MHChipVariant, active: Bool) -> MHChipSpec {
            MHChipSpec(variant: v, size: .medium, isActive: active,
                       contentColor: nil, backgroundColor: nil, activeColor: nil)
        }
        XCTAssertNil(spec(.solid, active: false).border(isEnabled: true))
        XCTAssertNil(spec(.solid, active: true).border(isEnabled: true))
        XCTAssertNil(spec(.solid, active: false).border(isEnabled: false))
        XCTAssertNotNil(spec(.outlined, active: false).border(isEnabled: true))
        XCTAssertNotNil(spec(.outlined, active: true).border(isEnabled: true))
        XCTAssertNotNil(spec(.outlined, active: false).border(isEnabled: false))
    }

    // customize: activeColor 가 활성 강조색을 덮어쓴다. background/foreground 도 override 를 반영.
    func testColorOverrides() {
        let solid = MHChipSpec(variant: .solid, size: .medium, isActive: true,
                               contentColor: nil, backgroundColor: nil, activeColor: .red)
        XCTAssertEqual(solid.activeAccent, .red)
        XCTAssertEqual(solid.background(isEnabled: true), .red)   // 활성 Solid 배경 = activeColor

        let inactive = MHChipSpec(variant: .solid, size: .medium, isActive: false,
                                  contentColor: .green, backgroundColor: .blue, activeColor: nil)
        XCTAssertEqual(inactive.foreground(isEnabled: true), .green)   // 비활성 콘텐츠색 override
        XCTAssertEqual(inactive.background(isEnabled: true), .blue)    // 비활성 배경 override
    }

    // 비활성화(disable) 글자색은 항상 Label/Disable.
    func testDisabledForeground() {
        for v in [MHChipVariant.solid, .outlined] {
            for active in [true, false] {
                let spec = MHChipSpec(variant: v, size: .medium, isActive: active,
                                      contentColor: .red, backgroundColor: nil, activeColor: nil)
                XCTAssertEqual(spec.foreground(isEnabled: false), .mhLabelDisable)
            }
        }
    }

    // 실제 렌더 높이가 Figma 고정 높이(24/32/36/40)와 일치.
    @MainActor
    func testRenderedHeightsMatchFigma() {
        MHFontRegistrar.registerIfNeeded()
        func h(_ size: MHChipSize) -> CGFloat {
            let r = ImageRenderer(content: MHChip("텍스트", size: size) {}); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }
        XCTAssertEqual(h(.xsmall), 24, accuracy: 0.5)
        XCTAssertEqual(h(.small), 32, accuracy: 0.5)
        XCTAssertEqual(h(.medium), 36, accuracy: 0.5)
        XCTAssertEqual(h(.large), 40, accuracy: 0.5)
    }
}
