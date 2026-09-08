import XCTest
import SwiftUI
@testable import DesignSystem

final class MHAvatarStackTests: XCTestCase {
    // 겹침 레이아웃 + pill 여백이 Figma 심볼 치수와 일치하는지.
    // 셀 레이아웃 32, 겹침 6(step 26), pill 여백 4/side.
    //   add     = 1 아바타 + "+" 버튼(2셀) → 32 + 26 + 8 = 66 × 40
    //   default = 4 아바타          → 32 + 3×26 + 8 = 118 × 40
    //   more    = 3 아바타 + 카운터(4셀) → 32 + 3×26 + 8 = 118 × 40
    //   both    = 3 아바타 + 카운터 + "+"(5셀) → 32 + 4×26 + 8 = 144 × 40
    @MainActor
    func testStackSizeMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        func size(_ view: some View) -> CGSize {
            let r = ImageRenderer(content: view); r.scale = 1
            return r.uiImage?.size ?? .zero
        }
        let add = size(MHAvatarStack([Image?.none], onAdd: { }))
        XCTAssertEqual(add.width, 66, accuracy: 0.5)
        XCTAssertEqual(add.height, 40, accuracy: 0.5)

        let def = size(MHAvatarStack(Array(repeating: Image?.none, count: 4)))
        XCTAssertEqual(def.width, 118, accuracy: 0.5)
        XCTAssertEqual(def.height, 40, accuracy: 0.5)

        let more = size(MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 99))
        XCTAssertEqual(more.width, 118, accuracy: 0.5)
        XCTAssertEqual(more.height, 40, accuracy: 0.5)

        // 카운터와 "+" 는 상호배타가 아니다 — 5명 이상인 공동방은 둘이 함께 선다.
        // PRD 「방 멤버 아바타」의 "아바타 3개 + 카운터 칩" 에 초대 버튼이 더해진 모양이다.
        let both = size(MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 4, onAdd: { }))
        XCTAssertEqual(both.width, 144, accuracy: 0.5)
        XCTAssertEqual(both.height, 40, accuracy: 0.5)
    }

    // 카운터 텍스트: 99 이하는 그대로, 초과 시 "99+" 로 캡(PRD "나머지 인원이 99명을 넘으면 `99+`").
    func testOverflowLabelCap() {
        XCTAssertEqual(MHAvatarCountBadge.text(5), "5")
        XCTAssertEqual(MHAvatarCountBadge.text(99), "99")
        XCTAssertEqual(MHAvatarCountBadge.text(100), "99+")
        XCTAssertEqual(MHAvatarCountBadge.text(1234), "99+")
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHAvatarStack 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhavatarstack_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // Figma 3 state 를 그대로 세로로 쌓은 대조용(같은 배율 합성에 사용).
    @MainActor
    func testStatesRender() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: States())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage)
        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhavatarstack_states.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// Figma variant 프레임(state=add/default/more)을 위→아래로 재현. 각 상태 hug.
private struct States: View {
    private let one = [Image?.none]
    private let four = Array(repeating: Image?.none, count: 4)
    private let three = Array(repeating: Image?.none, count: 3)
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            MHAvatarStack(one, onAdd: { })                                   // add
            MHAvatarStack(four)                                      // default
            MHAvatarStack(three, overflow: 99)           // more
        }
        .padding(16)
        .background(Color.white)
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            label("state · add / default / more")
            MHAvatarStack([Image?.none], onAdd: { })
            MHAvatarStack(Array(repeating: Image?.none, count: 4))
            MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 99)

            label("overflow · 5 / 12 / 100")
            HStack(spacing: 16) {
                MHAvatarStack(Array(repeating: Image?.none, count: 2), overflow: 5)
                MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 12)
                MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 100)
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
