import XCTest
import SwiftUI
@testable import DesignSystem

final class MHStatusMessageTests: XCTestCase {
    // T6 — `.failure` 는 다시 시도 자리가 추가로 그려져 `.progress` 보다 높아야 한다.
    // `.progress` 는 조회 중(UX-001), `.failure` 는 조회 실패(UX-002)·이어 붙이기 실패(UX-012).
    @MainActor
    func testFailureIsTallerThanProgress() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ kind: MHStatusMessageKind) throws -> CGFloat {
            let r = ImageRenderer(content:
                MHStatusMessage(message: "알림을 불러오지 못했어요", kind: kind).frame(width: 335))
            r.scale = 1
            return try XCTUnwrap(r.uiImage, "렌더 실패").size.height
        }
        let progress = try height(.progress)
        let failure = try height(.failure(retryTitle: "다시 시도", onRetry: {}))
        XCTAssertGreaterThan(failure, progress)
    }
}
