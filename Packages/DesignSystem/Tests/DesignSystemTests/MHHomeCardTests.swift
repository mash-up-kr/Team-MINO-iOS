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

    // 사진 수가 2 미만이어도 칸은 두 개 — 1장짜리 핀에서 타일 하나가 카드 폭을 다 차지해
    // 카드가 523pt 로 부풀던 문제(실기기 재현). 큰 원본(1080×1350)으로 재서 사진 크기에도 흔들리지 않게 한다.
    @MainActor
    func testHeightStaysFixedWithFewerThanTwoImages() throws {
        MHFontRegistrar.registerIfNeeded()
        for images in [[bigImage(.systemGray3)], []] {
            let card = MHHomeCard(
                avatar: nil, badgeText: "가볼 만한 곳", badgeColor: .mhAccentForegroundLime,
                title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", images: images
            ) { }
            let r = ImageRenderer(content: card.frame(width: 335))
            r.scale = 1
            XCTAssertEqual(r.uiImage?.size.height ?? 0, 328, accuracy: 1.0, "사진 \(images.count)장")
        }
    }

    // 사진이 없는 칸은 회색 자리표가 아니라 투명이어야 한다 — 회색은 "안 뜬 사진" 으로 읽힌다.
    // 사진이 올 칸(URL 있음)은 로딩 중에도 회색이 깔려야 자리가 비지 않는다.
    // 에셋 색이 ImageRenderer 에서 투명으로 나와 픽셀로는 못 재고, 칸별 판정 규칙을 직접 검증한다.
    func testSlotSurfaceFollowsImageCount() {
        XCTAssertTrue(MHHomeCard.slotHasImage(imageCount: 1, index: 0), "1장: 첫 칸은 사진 자리")
        XCTAssertFalse(MHHomeCard.slotHasImage(imageCount: 1, index: 1), "1장: 둘째 칸은 투명")
        XCTAssertFalse(MHHomeCard.slotHasImage(imageCount: 0, index: 0), "0장: 모두 투명")
        XCTAssertFalse(MHHomeCard.slotHasImage(imageCount: 0, index: 1))
        XCTAssertTrue(MHHomeCard.slotHasImage(imageCount: 3, index: 1), "3장: 두 칸 모두 사진 자리")
    }

    @MainActor
    func testRemoteURLsKeepTwoTilesBeforeLoad() throws {
        MHFontRegistrar.registerIfNeeded()
        let card = MHHomeCard(
            avatar: nil, badgeText: "가볼 만한 곳", badgeColor: .mhAccentForegroundLime,
            title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            imageURLs: [URL(string: "https://cdn.example.com/a.jpg")!]
        ) { }
        let r = ImageRenderer(content: card.frame(width: 335))
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

private func bigImage(_ color: UIColor) -> Image {
    let size = CGSize(width: 1080, height: 1350)
    let ui = UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
    }
    return Image(uiImage: ui)
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
