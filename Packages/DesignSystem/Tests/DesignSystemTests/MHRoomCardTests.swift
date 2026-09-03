import XCTest
import SwiftUI
@testable import DesignSystem

final class MHRoomCardTests: XCTestCase {
    // 썸네일 렌더(마스코트 에셋 로드 확인) — 80pt 정사각.
    @MainActor
    func testThumbnailRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHRoomThumbnail()); r.scale = 1
        let img = try XCTUnwrap(r.uiImage, "MHRoomThumbnail 렌더 실패")
        XCTAssertEqual(img.size.width, 80, accuracy: 0.5)
        XCTAssertEqual(img.size.height, 80, accuracy: 0.5)
    }

    // 행 높이: 썸네일 80 + py12*2 = 104 (썸네일이 가장 큼).
    @MainActor
    func testRowHeight() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, members: [nil]).frame(width: 375))
        r.scale = 1
        XCTAssertEqual(r.uiImage?.size.height ?? 0, 104, accuracy: 1.0)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHRoomCard 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhroomcard_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// Figma 4 variant(showMemo × showListCell)를 위→아래로.
private struct Gallery: View {
    @State private var picked = true
    var body: some View {
        VStack(spacing: 0) {
            MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, members: [nil])  // memo, avatar
            MHRoomCard(title: "내 방", placeCount: 0, members: [nil])                             // no memo, avatar
            MHRoomCard(title: "내 방", placeCount: 0, selection: .constant(false))               // no memo, checkbox
            MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, selection: .constant(false)) // memo, checkbox
        }
        .frame(width: 375)
        .padding(16)
        .background(Color.white)
    }
}
