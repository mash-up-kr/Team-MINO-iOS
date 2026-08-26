import XCTest
import SwiftUI
@testable import DesignSystem

final class MHIllustratedMessageTests: XCTestCase {
    // T4 — `.center` 와 `.leading` 이 서로 다르게 그려진다. 정렬을 통째로 무시해도
    // nil 아님 단언은 통과하므로, 같은 입력을 두 번 렌더해 픽셀(pngData)이 실제로 갈리는지 본다.
    @MainActor
    func testCenterAndLeadingRenderDifferently() throws {
        MHFontRegistrar.registerIfNeeded()
        func render(_ alignment: MHIllustratedMessageAlignment) throws -> Data {
            let r = ImageRenderer(content:
                MHIllustratedMessage(
                    illustration: Image(systemName: "bell.slash"),
                    title: "받은 알림이 없어요",
                    messages: ["새 알림이 오면 여기에 표시돼요"],
                    alignment: alignment,
                    illustrationSpacing: 32
                ).frame(width: 375))
            r.scale = 1
            let img = try XCTUnwrap(r.uiImage, "렌더 실패")
            return try XCTUnwrap(img.pngData(), "PNG 인코딩 실패")
        }
        let center = try render(.center)
        let leading = try render(.leading)
        XCTAssertNotEqual(center, leading)
    }

    // T5 — 저장 오류 안내(본문 3줄)가 빈 상태(본문 없음)보다 본문만큼 더 높다.
    @MainActor
    func testMessagesAddHeight() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ messages: [String]) throws -> CGFloat {
            let r = ImageRenderer(content:
                MHIllustratedMessage(
                    illustration: Image(systemName: "bell.slash"),
                    title: "확인해주세요",
                    messages: messages
                ).frame(width: 375))
            r.scale = 1
            return try XCTUnwrap(r.uiImage, "렌더 실패").size.height
        }
        let withMessages = try height([
            "현재 한국 내 장소만 지원됩니다.",
            "사진 속 장소인식은 아직 지원하지 않습니다",
            "본문에 주소나 장소명을 포함해주세요"
        ])
        let withoutMessages = try height([])
        XCTAssertGreaterThan(withMessages, withoutMessages)
    }

    // T8 — illustrationSpacing 이 정렬이 아니라 실제 파라미터로 동작하는지: 32 → 103 이면
    // 전체 높이가 늘린 만큼(71, ±1) 늘어난다.
    @MainActor
    func testIllustrationSpacingAffectsHeight() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ spacing: CGFloat) throws -> CGFloat {
            let r = ImageRenderer(content:
                MHIllustratedMessage(
                    illustration: Image(systemName: "bell.slash"),
                    title: "받은 알림이 없어요",
                    illustrationSpacing: spacing
                ).frame(width: 375))
            r.scale = 1
            return try XCTUnwrap(r.uiImage, "렌더 실패").size.height
        }
        let narrow = try height(32)
        let wide = try height(103)
        XCTAssertEqual(wide - narrow, 71, accuracy: 1.0)
    }
}
