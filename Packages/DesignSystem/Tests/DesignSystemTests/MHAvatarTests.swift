import XCTest
import SwiftUI
@testable import DesignSystem

final class MHAvatarTests: XCTestCase {
    // person=원(크기/2), company·academy=크기×0.25(홀수면 짝수로 올림, Figma 규칙).
    func testCornerRadius() {
        // person → 원
        XCTAssertEqual(MHAvatarVariant.person.cornerRadius(size: 40), 20)
        XCTAssertEqual(MHAvatarVariant.person.cornerRadius(size: 56), 28)
        // company/academy 기본 사이즈 → size×0.25 (짝수)
        XCTAssertEqual(MHAvatarVariant.company.cornerRadius(size: 24), 6)
        XCTAssertEqual(MHAvatarVariant.company.cornerRadius(size: 40), 10)
        XCTAssertEqual(MHAvatarVariant.academy.cornerRadius(size: 56), 14)
        // 커스텀: 0.25배가 홀수면 짝수로 올림 (44×0.25=11 → 12, 52×0.25=13 → 14)
        XCTAssertEqual(MHAvatarVariant.company.cornerRadius(size: 44), 12)
        XCTAssertEqual(MHAvatarVariant.company.cornerRadius(size: 52), 14)
    }

    // 렌더 크기가 size 정사각과 일치(배지 없을 때).
    @MainActor
    func testRenderedSizeIsSquare() {
        MHFontRegistrar.registerIfNeeded()
        func size(_ s: CGFloat) -> CGSize {
            let r = ImageRenderer(content: MHAvatar(nil, size: s)); r.scale = 1
            return r.uiImage?.size ?? .zero
        }
        for s in [CGFloat(24), 32, 40, 48, 56] {
            let rendered = size(s)
            XCTAssertEqual(rendered.width, s, accuracy: 0.5)
            XCTAssertEqual(rendered.height, s, accuracy: 0.5)
        }
    }
}
