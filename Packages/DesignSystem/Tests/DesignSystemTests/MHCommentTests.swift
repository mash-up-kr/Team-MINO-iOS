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

    // dateText 는 본문 컨테이너 안에 gap 4 로 붙는다(Figma comment 4942:209197, Caption 2 = 11 × 1.273 ≈ 14pt).
    //   normal(1줄) + 날짜 = 32 + 10 + 20 + 4 + 14 = 80
    //   full(클립)  + 날짜 = 182 그대로 — 컨테이너 max-h 140 을 본문(122)과 날짜가 나눠 쓴다
    // (렌더된 이미지에서 문자열 내용·정렬 자체를 검증할 수는 없다 — 높이로만 본다.)
    @MainActor
    func testHeightWithDateText() throws {
        MHFontRegistrar.registerIfNeeded()
        func height(_ comment: String) -> CGFloat {
            let r = ImageRenderer(content:
                MHComment(avatar: nil, name: "이름", comment: comment, dateText: "2027.01.01").frame(width: 335))
            r.scale = 1
            return r.uiImage?.size.height ?? 0
        }
        XCTAssertEqual(height("친구가 남긴 코멘트입니다."), 80, accuracy: 1.0)

        let long = String(repeating: "친구가 남긴 코멘트입니다.", count: 20)
        XCTAssertEqual(height(long), 182, accuracy: 1.0)   // 본문 122 에서 잘리고 날짜는 보인다
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
