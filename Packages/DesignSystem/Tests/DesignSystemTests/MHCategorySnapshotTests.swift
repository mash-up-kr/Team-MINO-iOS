import XCTest
import SwiftUI
@testable import DesignSystem

final class MHCategorySnapshotTests: XCTestCase {
    // ImageRenderer 는 ScrollView 를 렌더하지 못한다(TextField·mhShadow 와 동일 한계).
    // → MHCategory 전체(스크롤/페이드/패딩)는 시뮬레이터로 확인하고, 여기선 칩 행의 시각 정합만 렌더한다.
    // 칩 행은 MHCategory 와 동일 규칙(variant+활성→solid/outlined, size→chipSize)으로 구성한다.
    @MainActor
    func testChipRowGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHCategory 칩 행 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/8d4054e0-f43f-4405-b167-77aae83b9180/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhcategory_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// MHCategory 의 칩 매핑을 그대로 재현한 검증용 행(스크롤 래퍼 제외).
private struct CatRow: View {
    let variant: MHCategoryVariant
    let size: MHCategorySize
    let count: Int
    var activeIndex = 0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                let active = i == activeIndex
                let cv: MHChipVariant = (variant == .normal && active) ? .solid : .outlined
                MHChip("텍스트", variant: cv, size: size.chip, isActive: active) {}
            }
        }
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            label("variant · normal / alternative (활성=첫 칩)")
            CatRow(variant: .normal, size: .medium, count: 5)
            CatRow(variant: .alternative, size: .medium, count: 5)

            label("size · small(24) / medium(32) / large(36) / xLarge(40)")
            CatRow(variant: .normal, size: .small, count: 4)
            CatRow(variant: .normal, size: .medium, count: 4)
            CatRow(variant: .normal, size: .large, count: 4)
            CatRow(variant: .normal, size: .xLarge, count: 4)
        }
        .padding(24)
        .background(Color.white)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
