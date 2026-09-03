import XCTest
import SwiftUI
@testable import DesignSystem

final class MHTooltipSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHTooltip 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        // 기본값은 이 머신의 임시 디렉토리 — 예전엔 특정 세션의 스크래치패드 절대경로가 박혀 있어
        // 다른 환경에서는 `try?` 에 삼켜진 채 조용히 쓰기에 실패했다.
        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"] ?? NSTemporaryDirectory()
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhtooltip_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // 높이는 전부 고정 상수(`Metric`)로 결정되므로 폭과 달리 오차 허용치를 두지 않는다 —
    // 느슨하게 두면 화살표 깊이가 바뀌어도 통과해, 실제로 그렇게 어긋난 채 방치됐다
    // (`6e3a207` 이 화살표를 Figma 리소스 실측으로 줄였는데 이 단언은 따라오지 않았다).
    // 폭만 텍스트 hug 라 폰트 렌더에 따라 흔들려 허용치를 남긴다.

    // Medium/Bottom 툴팁 크기 — Figma 169×42.
    @MainActor
    func testMediumBottomSizeMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHTooltip("메시지에 마침표를 찍어요."))
        r.scale = 1
        let size = try XCTUnwrap(r.uiImage).size
        XCTAssertEqual(size.width, 169, accuracy: 1.5)     // 텍스트 hug + px12
        XCTAssertEqual(size.height, 42, accuracy: 0.5)     // 라인박스 20 + py8×2 + 화살표 6(리소스 20×5.924)
    }

    // Small/Bottom 툴팁 크기 — Figma 36×29.
    @MainActor
    func testSmallSizeMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHTooltip("역할", size: .small))
        r.scale = 1
        let size = try XCTUnwrap(r.uiImage).size
        XCTAssertEqual(size.width, 36, accuracy: 1.5)      // "역할" hug(minW 36) + px8
        XCTAssertEqual(size.height, 29, accuracy: 0.5)     // 라인박스 14 + py5×2 + 화살표 5(리소스 14×5)
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            label("size · medium / small")
            HStack(spacing: 40) {
                MHTooltip("메시지에 마침표를 찍어요.")
                MHTooltip("역할", size: .small)
            }

            label("position (medium, align center)")
            HStack(spacing: 40) {
                MHTooltip("Top", position: .top)
                MHTooltip("Bottom", position: .bottom)
                MHTooltip("Left", position: .left)
                MHTooltip("Right", position: .right)
            }

            label("align (position bottom) · start / center / end")
            HStack(spacing: 40) {
                MHTooltip("메시지", position: .bottom, align: .start)
                MHTooltip("메시지", position: .bottom, align: .center)
                MHTooltip("메시지", position: .bottom, align: .end)
            }

            label("align (position right) · start / center / end")
            HStack(spacing: 40) {
                MHTooltip("메시지", position: .right, align: .start)
                MHTooltip("메시지", position: .right, align: .center)
                MHTooltip("메시지", position: .right, align: .end)
            }

            label("shortcut")
            HStack(spacing: 40) {
                MHTooltip("메시지에 마침표를 찍어요.", shortcut: "⌘C")
                MHTooltip("역할", shortcut: "⌘C", size: .small)
            }
        }
        .padding(40)
        .background(Color(white: 0.90))
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
