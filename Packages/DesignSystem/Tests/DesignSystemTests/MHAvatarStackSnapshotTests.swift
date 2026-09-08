import SwiftUI
import XCTest
@testable import DesignSystem

/// 아바타 스택의 카운터 칩 갤러리를 렌더한다.
///
/// PRD 「방 멤버 아바타」 — *"4명 이하: 있는 대로 모두 겹쳐 표시하고 카운터는 붙이지 않는다 /
/// 5명 이상: 아바타 3개 + 카운터 칩"*, *"나머지가 99명을 넘으면 `99+`"*.
///
/// 5명 이상인 공동방은 **카운터와 `+` 가 함께** 서야 해 경계가 눈으로 확인돼야 한다.
final class MHAvatarStackSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "MHAvatarStack 갤러리 렌더 실패")
        XCTAssertGreaterThan(image.size.width, 0)

        guard let dir = ProcessInfo.processInfo.environment["SNAP_DIR"] else { return }
        if let data = image.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhavatarstack_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    /// 카운터가 붙으면 스택이 넓어진다 — nil 아님만 보면 `overflow` 를 무시하는 구현도 통과한다.
    @MainActor
    func testCounterWidensStack() throws {
        func width(overflow: Int?) -> CGFloat {
            let renderer = ImageRenderer(
                content: MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: overflow)
            )
            renderer.scale = 1
            return renderer.uiImage?.size.width ?? 0
        }
        XCTAssertGreaterThan(width(overflow: 4), width(overflow: nil))
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row("멤버 1명 — 카운터 없음", avatars(1), overflow: nil)
            row("멤버 4명 — 경계, 카운터 없음", avatars(4), overflow: nil)
            row("멤버 5명 — 아바타 3 + 카운터 2", avatars(3), overflow: 2)
            row("멤버 7명 — 아바타 3 + 카운터 4 (PRD 예시)", avatars(3), overflow: 4)
            row("나머지 99명 초과 — 99+", avatars(3), overflow: 120)
            row("공동방 — 카운터와 + 가 함께 선다", avatars(3), overflow: 4, add: true)
        }
        .padding(24)
        .background(Color.white)
    }

    private func avatars(_ count: Int) -> [Image?] {
        Array(repeating: Image?.none, count: count)
    }

    private func row(
        _ label: String,
        _ images: [Image?],
        overflow: Int?,
        add: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).mhTypography(.caption1Medium).foregroundStyle(Color.mhLabelAlternative)
            MHAvatarStack(images, overflow: overflow, onAdd: add ? {} : nil)
        }
    }
}
