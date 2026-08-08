import XCTest
import SwiftUI
@testable import DesignSystem

final class MHRoomHeaderTests: XCTestCase {
    // Figma 심볼 높이와 일치: show memo=on 122, off 98 (폭 375).
    //   on  = pt12 + [제목32 + gap4 + 메모20] + gap10 + 메타행24 + pb20 = 122
    //   off = pt12 + 제목32           + gap10 + 메타행24 + pb20 = 98
    @MainActor
    func testHeightMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ view: some View) -> CGFloat {
            let r = ImageRenderer(content: view.frame(width: 375)); r.scale = 1
            return r.uiImage?.size.height ?? 0
        }
        let on = height(MHRoomHeader(title: "Title", memo: "memo", count: "999+개") { })
        XCTAssertEqual(on, 122, accuracy: 1.0)

        let off = height(MHRoomHeader(title: "Title", count: "999+개") { })
        XCTAssertEqual(off, 98, accuracy: 1.0)
    }

    // 폭은 부모를 채운다(maxWidth infinity).
    @MainActor
    func testFillsWidth() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHRoomHeader(title: "Title", memo: "memo", count: "999+개") { }.frame(width: 375))
        r.scale = 1
        XCTAssertEqual(r.uiImage?.size.width ?? 0, 375, accuracy: 0.5)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHRoomHeader 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhroomheader_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// Figma 두 state(on/off)를 위→아래로. 대조용(scale=3).
private struct Gallery: View {
    var body: some View {
        VStack(spacing: 30) {
            MHRoomHeader(title: "Title", memo: "memo", count: "999+개") { }   // on
            MHRoomHeader(title: "Title", count: "999+개") { }                  // off
        }
        .frame(width: 375)
        .padding(16)
        .background(Color.white)
    }
}
