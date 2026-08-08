import XCTest
import SwiftUI
@testable import DesignSystem

final class MHTopNavigationTests: XCTestCase {
    // 높이 = 상하 패딩 10*2 + 콘텐츠 최소 24 = 44.
    // 세 요소가 모두 선택이라, 아무것도 안 넘겨도 이 높이를 유지해야 화면 상단이 흔들리지 않는다.
    @MainActor
    func testHeightStaysConstantAcrossSlots() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ view: some View) -> CGFloat {
            let r = ImageRenderer(content: view.frame(width: 375)); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }

        XCTAssertEqual(height(MHTopNavigation(title: "공동방 만들기", onBack: {}, onSkip: {})), 44, accuracy: 1.0)
        XCTAssertEqual(height(MHTopNavigation(title: "프로필 설정")), 44, accuracy: 1.0)
        XCTAssertEqual(height(MHTopNavigation(onBack: {}, onSkip: {})), 44, accuracy: 1.0)
        XCTAssertEqual(height(MHTopNavigation()), 44, accuracy: 1.0)
    }

    // 타이틀은 가운데 고정이고 버튼은 좌우 끝에 겹쳐 얹힌다 — 긴 타이틀이 버튼을 밀어내
    // 높이를 늘리거나 폭을 넘기면 안 된다(lineLimit 1).
    @MainActor
    func testLongTitleDoesNotGrowHeight() throws {
        MHFontRegistrar.registerIfNeeded()
        let long = String(repeating: "긴제목", count: 20)
        let r = ImageRenderer(content:
            MHTopNavigation(title: long, onBack: {}, onSkip: {}).frame(width: 375))
        r.scale = 1
        let size = try XCTUnwrap(r.uiImage?.size)
        XCTAssertEqual(size.height, 44, accuracy: 1.0)
        XCTAssertEqual(size.width, 375, accuracy: 0.5)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHTopNavigation 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)
    }

    private struct Gallery: View {
        var body: some View {
            VStack(spacing: 0) {
                MHTopNavigation(title: "공동방 만들기", onBack: {}, onSkip: {})
                MHTopNavigation(title: "프로필 설정")
                MHTopNavigation(onBack: {}, onSkip: {})
            }
            .frame(width: 375)
        }
    }
}
