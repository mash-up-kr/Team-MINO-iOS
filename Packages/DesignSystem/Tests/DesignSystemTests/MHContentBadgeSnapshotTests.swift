import XCTest
import SwiftUI
@testable import DesignSystem

final class MHContentBadgeSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHContentBadge 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/1d2ce843-5ebb-4a15-94d3-23177ec7a631/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhcontentbadge_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

private struct Gallery: View {
    private let sizes: [MHContentBadgeSize] = [.xsmall, .small, .medium]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            row("Solid · Neutral", variant: .solid, color: nil)
            row("Outlined · Neutral", variant: .outlined, color: nil)
            row("Solid · Accent(cyan)", variant: .solid, color: .mhAccentForegroundCyan)
            row("Outlined · Accent(cyan)", variant: .outlined, color: .mhAccentForegroundCyan)
            HStack(spacing: 8) {
                MHContentBadge("인기", leadingIcon: .star)
                MHContentBadge("추천", variant: .outlined, trailingIcon: .arrowRight)
                MHContentBadge("BETA", size: .medium, color: .mhAccentForegroundViolet, leadingIcon: .bell)
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func row(_ label: String, variant: MHContentBadgeVariant, color: Color?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    MHContentBadge("텍스트", variant: variant, size: sizes[i], color: color)
                }
            }
        }
    }
}
