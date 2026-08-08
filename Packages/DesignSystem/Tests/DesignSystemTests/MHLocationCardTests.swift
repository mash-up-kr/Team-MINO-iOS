import XCTest
import SwiftUI
@testable import DesignSystem

final class MHLocationCardTests: XCTestCase {
    // compact — 썸네일 왼쪽 94 정사각 + py12*2 = 118 이 최소 행 높이(콘텐츠보다 썸네일이 큼).
    @MainActor
    func testCompactRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                           commentCount: 8, members: [nil]).frame(width: 335))
        r.scale = 1
        let img = try XCTUnwrap(r.uiImage, "MHLocationCard(compact) 렌더 실패")
        XCTAssertEqual(img.size.width, 335, accuracy: 1.0)
        XCTAssertEqual(img.size.height, 118, accuracy: 1.0)
    }

    // expanded — 가로 꽉 채운 4:3 썸네일이 포함돼 compact 보다 훨씬 높다.
    @MainActor
    func testExpandedIsTallerThanCompact() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ layout: MHLocationCardLayout) throws -> CGFloat {
            let r = ImageRenderer(content:
                MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                               commentCount: 8, members: [nil], layout: layout).frame(width: 335))
            r.scale = 1
            return try XCTUnwrap(r.uiImage, "렌더 실패").size.height
        }
        XCTAssertGreaterThan(try height(.expanded), try height(.compact))
    }

    // 멤버가 없으면 아바타 그룹을 숨겨도 렌더가 깨지지 않는다.
    @MainActor
    func testNoMembersRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHLocationCard(title: "제목", address: "주소", commentCount: 0).frame(width: 335))
        r.scale = 1
        XCTAssertNotNil(r.uiImage, "멤버 없는 MHLocationCard 렌더 실패")
    }

    // 메뉴 항목을 넘겨도(닫힌 상태) 카드가 정상 렌더된다.
    @MainActor
    func testWithMenuItemsRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
                           menuItems: [MHMenuItem("다른 방에 공유") {}, MHMenuItem("장소 삭제") {}])
                .frame(width: 335))
        r.scale = 1
        XCTAssertNotNil(r.uiImage, "menuItems 넘긴 MHLocationCard 렌더 실패")
    }

    // 메뉴 열린 상태(below·above)가 크래시 없이 렌더된다. (MHMenu 항목 텍스트는 ImageRenderer
    // 미지원이라 시뮬레이터에서만 육안 확인 — 여기선 앵커/합성이 깨지지 않음만 보장.)
    @MainActor
    func testMenuOpenRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let items = [MHMenuItem("다른 방에 공유") {}, MHMenuItem("장소 삭제") {}, MHMenuItem("장소 이동") {}]
        for placement in [MHLocationCardMenuPlacement.below, .above] {
            let r = ImageRenderer(content:
                MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
                               members: [nil], menuItems: items, menuPlacement: placement,
                               menuPresented: .constant(true)).frame(width: 335))
            r.scale = 1
            XCTAssertNotNil(r.uiImage, "메뉴 열림(\(placement)) 렌더 실패")
        }
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHLocationCard 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-501/-Users-kim-yubeen-dev--------Team-MINO-iOS/5c6a0339-f6d0-471e-9519-76b43a0fb4a6/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhlocationcard_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// compact(999+ 절단) → compact(멤버 없음) → expanded 순으로.
private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                           commentCount: 1200, members: [nil, nil])           // compact, 999+
            MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                           commentCount: 8)                                    // compact, 멤버·아바타 없음
            MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                           commentCount: 8, members: [nil], layout: .expanded) // expanded
        }
        .frame(width: 335)
        .padding(16)
        .background(Color.white)
    }
}
