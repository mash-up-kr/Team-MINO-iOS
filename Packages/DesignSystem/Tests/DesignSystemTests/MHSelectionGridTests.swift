import XCTest
import SwiftUI
@testable import DesignSystem

final class MHSelectionGridTests: XCTestCase {
    private static func swatches(_ count: Int) -> [MHSelectionGridItem] {
        Array(repeating: .color(fill: .mhRed60, border: .mhRed30), count: count)
    }

    // 4열 고정 그리드 — 칸 70, 간격 10. 12칸이면 3행이라
    // 높이 = 제목20 + titleSpacing + (70*3 + 10*2) = 제목20 + spacing + 230.
    // shape 이 titleSpacing 을 가르므로(circle 16 / roundedSquare 20) 두 형태의 높이가 4 만큼 벌어진다.
    @MainActor
    func testShapeChangesTitleSpacingOnly() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ shape: MHSelectionGridShape) -> CGFloat {
            let view = MHSelectionGrid(
                title: "제목",
                items: Self.swatches(12),
                selectedIndex: nil,
                shape: shape,
                identifierPrefix: "Test.grid",
                onSelect: { _ in }
            )
            let r = ImageRenderer(content: view.frame(width: 320)); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }

        XCTAssertEqual(height(.roundedSquare) - height(.circle), 4, accuracy: 1.0)
    }

    // 칸이 4개 늘 때마다 한 행(70 + 간격 10)이 는다 — 열 수가 4로 고정돼 있다는 뜻.
    @MainActor
    func testRowGrowsEveryFourItems() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ count: Int) -> CGFloat {
            let view = MHSelectionGrid(
                title: "제목",
                items: Self.swatches(count),
                selectedIndex: nil,
                shape: .circle,
                identifierPrefix: "Test.grid",
                onSelect: { _ in }
            )
            let r = ImageRenderer(content: view.frame(width: 320)); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }

        XCTAssertEqual(height(8) - height(4), 80, accuracy: 1.0)
        XCTAssertEqual(height(4), height(1), accuracy: 1.0)   // 1~4칸은 모두 한 행
    }

    // 선택 표시가 칸 바깥으로 나가도(원형은 링을 -3 만큼 바깥에 그린다) 레이아웃을 밀지 않아야 한다.
    @MainActor
    func testSelectionDoesNotChangeLayout() throws {
        MHFontRegistrar.registerIfNeeded()
        func size(_ selected: Int?) -> CGSize {
            let view = MHSelectionGrid(
                title: "제목",
                items: Self.swatches(12),
                selectedIndex: selected,
                shape: .circle,
                identifierPrefix: "Test.grid",
                onSelect: { _ in }
            )
            let r = ImageRenderer(content: view.frame(width: 320)); r.scale = 1
            return r.uiImage?.size ?? .zero
        }

        XCTAssertEqual(size(nil).height, size(0).height, accuracy: 1.0)
        XCTAssertEqual(size(nil).width, size(0).width, accuracy: 0.5)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHSelectionGrid 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)
    }

    private struct Gallery: View {
        var body: some View {
            VStack(spacing: 20) {
                MHSelectionGrid(
                    title: "프로필 이미지 선택",
                    items: MHSelectionGridTests.swatches(12),
                    selectedIndex: 1,
                    shape: .circle,
                    identifierPrefix: "Gallery.character",
                    onSelect: { _ in }
                )
                MHSelectionGrid(
                    title: "방 색상 선택",
                    items: MHSelectionGridTests.swatches(12),
                    selectedIndex: 5,
                    shape: .roundedSquare,
                    identifierPrefix: "Gallery.color",
                    onSelect: { _ in }
                )
            }
            .padding(20)
            .frame(width: 375)
        }
    }
}
