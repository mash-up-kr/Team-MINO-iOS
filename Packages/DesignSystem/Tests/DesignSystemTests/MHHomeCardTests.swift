import XCTest
import SwiftUI
@testable import DesignSystem

final class MHHomeCardTests: XCTestCase {
    // Figma 심볼 높이(폭 335): py20 + 헤더(아바타행32 + gap12 + 제목24+gap2+주소18=44)=88 + gap16 + 이미지184 + py20 = 328.
    @MainActor
    func testHeightMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: card(.mhAccentForegroundLightBlue, "친구들이 많이 본 곳").frame(width: 335))
        r.scale = 1
        XCTAssertEqual(r.uiImage?.size.height ?? 0, 328, accuracy: 1.0)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHHomeCard 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhhomecard_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

@MainActor
private func card(_ color: Color, _ text: String) -> MHHomeCard {
    MHHomeCard(
        avatar: nil, badgeText: text, badgeColor: color,
        title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
        images: [solidImage(.systemGray3), solidImage(.systemGray4)]
    ) { }
}

private func solidImage(_ color: UIColor) -> Image {
    let size = CGSize(width: 120, height: 150)
    let ui = UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
    }
    return Image(uiImage: ui)
}

// Figma 4 variant(뱃지 문구·강조색만 다름)를 세로로. 대조용(scale=3).
private struct Gallery: View {
    var body: some View {
        VStack(spacing: 16) {
            card(.mhAccentForegroundLightBlue, "친구들이 많이 본 곳")
            card(.mhAccentForegroundPink, "이야기 많은 곳")
            card(.mhAccentForegroundRedOrange, "여럿이 저장한 곳")
            card(.mhAccentForegroundLime, "가볼 만한 곳")
        }
        .frame(width: 335)
        .padding(16)
        .background(Color.white)
    }
}
