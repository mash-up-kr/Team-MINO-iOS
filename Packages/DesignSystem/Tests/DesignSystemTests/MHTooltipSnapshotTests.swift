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

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/8d4054e0-f43f-4405-b167-77aae83b9180/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhtooltip_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // Medium/Bottom 툴팁 크기가 Figma(169×44)와 일치하는지 — 버블 라인박스 고정 + 화살표 8pt.
    @MainActor
    func testMediumBottomSizeMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHTooltip("메시지에 마침표를 찍어요."))
        r.scale = 1
        let size = try XCTUnwrap(r.uiImage).size
        XCTAssertEqual(size.width, 169, accuracy: 1.5)    // 텍스트 hug + px12
        XCTAssertEqual(size.height, 44, accuracy: 1.5)    // 라인박스 20 + py8×2 + 화살표 8
    }

    // Small/Bottom 툴팁 크기가 Figma(36×30)와 일치하는지.
    @MainActor
    func testSmallSizeMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHTooltip("역할", size: .small))
        r.scale = 1
        let size = try XCTUnwrap(r.uiImage).size
        XCTAssertEqual(size.width, 36, accuracy: 1.5)     // "역할" hug(minW 36) + px8
        XCTAssertEqual(size.height, 30, accuracy: 1.5)    // 라인박스 14 + py5×2 + 화살표 6
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
