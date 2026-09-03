import XCTest
import SwiftUI
@testable import DesignSystem

final class MHMenuSnapshotTests: XCTestCase {
    // ImageRenderer 는 ScrollView·mhShadow 를 렌더하지 못한다 → 전체 시각(카드·셀·그림자·스크롤·액션영역)은
    // 시뮬레이터로 확인한다. 여기선 컴파일 + 렌더 스모크(비영 크기)만 본다.
    @MainActor
    func testMenuRendersNonEmpty() throws {
        MHFontRegistrar.registerIfNeeded()
        let menu = MHMenu(
            (0..<5).map { i in MHMenuItem("텍스트 \(i)") {} },
            maxHeight: 300
        ).frame(width: 320)
        let r = ImageRenderer(content: menu)
        r.scale = 2
        let img = try XCTUnwrap(r.uiImage, "MHMenu 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)
        XCTAssertGreaterThan(img.size.height, 0)
    }
}
