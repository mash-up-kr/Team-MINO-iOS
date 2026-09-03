import XCTest
import SwiftUI
@testable import DesignSystem

final class MHCommentTests: XCTestCase {
    // Figma 심볼 높이(폭 335): 헤더(아바타 32) + gap10 + 본문.
    //   normal(1줄)  = 32 + 10 + 20  = 62
    //   full(140 캡) = 32 + 10 + 140 = 182
    @MainActor
    func testHeightMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ comment: String) -> CGFloat {
            let r = ImageRenderer(content:
                MHComment(avatar: nil, name: "이름", comment: comment).frame(width: 335))
            r.scale = 1
            return r.uiImage?.size.height ?? 0
        }
        XCTAssertEqual(height("친구가 남긴 코멘트입니다."), 62, accuracy: 1.0)

        let long = String(repeating: "친구가 남긴 코멘트입니다.", count: 20)
        XCTAssertEqual(height(long), 182, accuracy: 1.0)   // 본문 140 에서 잘림
    }

    // dateText 는 본문 아래 우측 하단에 한 행을 더한다(시안 2026-09-03) — caption1 = 12 × 1.334 ≈ 16pt.
    //   normal(1줄) + 날짜 = 62 + gap10 + 16 = 88
    // (렌더된 이미지에서 문자열 내용·정렬 자체를 검증할 수는 없다 — 높이로 행이 생겼는지만 본다.)
    @MainActor
    func testHeightGrowsByDateRow() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHComment(avatar: nil, name: "이름", comment: "친구가 남긴 코멘트입니다.", dateText: "3일 전")
                .frame(width: 335))
        r.scale = 1
        XCTAssertEqual(r.uiImage?.size.height ?? 0, 88, accuracy: 1.0)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHComment 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhcomment_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// Figma 3 state(normal/half/full)를 위→아래로. 대조용(scale=3).
private struct Gallery: View {
    private let unit = "친구가 남긴 코멘트입니다."
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MHComment(avatar: nil, name: "이름", comment: unit)                              // normal
            MHComment(avatar: nil, name: "이름", comment: String(repeating: unit, count: 7)) // half
            MHComment(avatar: nil, name: "이름", comment: String(repeating: unit, count: 20))// full(잘림)
        }
        .frame(width: 335)
        .padding(16)
        .background(Color.white)
    }
}
