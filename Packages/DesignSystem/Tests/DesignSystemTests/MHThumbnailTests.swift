import XCTest
import SwiftUI
@testable import DesignSystem

final class MHThumbnailTests: XCTestCase {
    func testCornerRadius() {
        XCTAssertEqual(MHThumbnailMetric.cornerRadius, 12)
    }

    // 이름값 ratio 프리셋이 Figma 값(가로/세로)과 일치.
    func testRatioPresets() {
        XCTAssertEqual(MHThumbnailRatio.square.value, 1, accuracy: 0.0001)
        XCTAssertEqual(MHThumbnailRatio.r16x9.value, 16.0/9.0, accuracy: 0.0001)
        XCTAssertEqual(MHThumbnailRatio.r21x9.value, 21.0/9.0, accuracy: 0.0001)
        XCTAssertEqual(MHThumbnailRatio.r3x4.value, 3.0/4.0, accuracy: 0.0001)      // 세로
        XCTAssertEqual(MHThumbnailRatio.r9x16.value, 9.0/16.0, accuracy: 0.0001)    // 세로
        XCTAssertEqual(MHThumbnailRatio.golden.value, 1.618, accuracy: 0.0001)
        XCTAssertEqual(MHThumbnailRatio(2.35).value, 2.35, accuracy: 0.0001)         // 커스텀
    }

    // 주어진 폭에서 ratio(가로/세로)로 높이가 결정된다.
    @MainActor
    func testRatioSizing() {
        MHFontRegistrar.registerIfNeeded()
        func size(_ ratio: MHThumbnailRatio, width: CGFloat) -> CGSize {
            let r = ImageRenderer(content: MHThumbnail(Image(systemName: "photo"), ratio: ratio).frame(width: width))
            r.scale = 1
            return r.uiImage?.size ?? .zero
        }
        let wide = size(.r16x9, width: 160)        // 16:9 → 160×90
        XCTAssertEqual(wide.width, 160, accuracy: 1); XCTAssertEqual(wide.height, 90, accuracy: 1)

        let square = size(.square, width: 100)     // 1:1 → 100×100
        XCTAssertEqual(square.height, 100, accuracy: 1)

        let portrait = size(.r3x4, width: 120)     // 3:4 → 120×160
        XCTAssertEqual(portrait.height, 160, accuracy: 1)
    }
}
