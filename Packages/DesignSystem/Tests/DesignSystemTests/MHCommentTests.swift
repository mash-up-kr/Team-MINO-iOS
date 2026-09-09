import XCTest
import SwiftUI
@testable import DesignSystem

final class MHCommentTests: XCTestCase {
    // Figma 심볼 높이(폭 335): 헤더(아바타 32) + gap10 + 본문.
    //   normal(1줄) = 32 + 10 + 20 = 62
    // 긴 본문은 **자르지 않는다** — 시안의 max-h 140 을 적용하면 6줄 뒤가 말줄임도 「더보기」도 없이
    // 사라져 글이 누락돼 보인다(2026-09-09 확정). 그래서 줄 수에 비례해 계속 커지는지만 본다.
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
        let longer = String(repeating: "친구가 남긴 코멘트입니다.", count: 40)
        XCTAssertGreaterThan(height(long), 182)            // 옛 140 캡을 넘어 다 보인다
        XCTAssertGreaterThan(height(longer), height(long))  // 길수록 계속 커진다(상한 없음)
    }

    // dateText 는 본문 컨테이너 안에 gap 4 로 붙는다(Figma comment 4942:209197, Caption 2 = 11 × 1.273 ≈ 14pt).
    //   normal(1줄) + 날짜 = 32 + 10 + 20 + 4 + 14 = 80
    // 긴 본문은 자르지 않으므로 날짜 행(4 + 14)만큼 더해진 높이가 나온다.
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
        XCTAssertGreaterThan(height(long), 182)   // 잘리지 않고 날짜 행까지 함께 늘어난다
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
