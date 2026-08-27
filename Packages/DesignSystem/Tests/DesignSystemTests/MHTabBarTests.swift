import XCTest
import SwiftUI
@testable import DesignSystem

final class MHTabBarTests: XCTestCase {
    /// `MHTabBar.height` 는 탭바 안쪽 스크롤 화면이 바닥 인셋으로 그대로 쓰는 값이라(``NotificationTabView``),
    /// 실제 렌더 높이와 어긋나면 마지막 셀이 탭바에 가리거나 빈 공간이 뜬다. 상수와 렌더를 대조한다.
    @MainActor
    func testDeclaredHeightMatchesRenderedHeight() throws {
        MHFontRegistrar.registerIfNeeded()

        let renderer = ImageRenderer(content: Host())
        renderer.scale = 1
        let size = try XCTUnwrap(renderer.uiImage, "MHTabBar 렌더 실패").size

        XCTAssertEqual(size.height, MHTabBar.height, accuracy: 0.5)
    }

    private struct Host: View {
        @State private var selected = 0

        var body: some View {
            MHTabBar(
                items: [
                    MHTabBarItem(id: 0, icon: .homeFill, label: "홈"),
                    MHTabBarItem(id: 1, icon: .folderFill, label: "저장"),
                    MHTabBarItem(id: 2, icon: .bellFill, label: "알림"),
                    MHTabBarItem(id: 3, icon: .personCircleFill, label: "마이페이지"),
                ],
                selectedID: $selected
            )
            .frame(width: 420)
        }
    }
}
