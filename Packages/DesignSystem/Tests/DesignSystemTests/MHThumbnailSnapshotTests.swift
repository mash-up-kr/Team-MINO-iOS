import XCTest
import SwiftUI
@testable import DesignSystem

final class MHThumbnailSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let sample = Image(uiImage: try XCTUnwrap(Self.sampleImage(), "샘플 이미지 생성 실패"))
        let renderer = ImageRenderer(content: Gallery(sample: sample))
        renderer.scale = 2
        let img = try XCTUnwrap(renderer.uiImage, "MHThumbnail 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/1d2ce843-5ebb-4a15-94d3-23177ec7a631/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhthumbnail_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // 비율 자르기가 보이도록 대각 그라디언트 + 격자 + 원을 그린 정사각 샘플.
    @MainActor static func sampleImage() -> UIImage? {
        let r = ImageRenderer(content:
            ZStack {
                LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.8), lineWidth: 8).padding(60)
                Text("SAMPLE").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            }.frame(width: 400, height: 400)
        )
        r.scale = 2
        return r.uiImage
    }
}

private struct Gallery: View {
    let sample: Image
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ratio (radius=true)").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                thumb("1:1", .square)
                thumb("4:3", .r4x3)
                thumb("16:9", .r16x9)
                thumb("3:4", .r3x4)
            }
            Text("radius=false(기본) · border · overlay").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                labeled("radius=false") { MHThumbnail(sample, ratio: .square).frame(width: 120) }
                labeled("border") { MHThumbnail(sample, ratio: .square, radius: true, border: true).frame(width: 120) }
                labeled("overlay") {
                    MHThumbnail(sample, ratio: .r16x9, radius: true) {
                        Text("12:34").mhTypography(.caption1Bold).foregroundStyle(.mhStaticWhite)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.black.opacity(0.5), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(6)
                    }.frame(width: 160)
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func thumb(_ label: String, _ ratio: MHThumbnailRatio) -> some View {
        labeled(label) { MHThumbnail(sample, ratio: ratio, radius: true).frame(width: 120) }
    }
    private func labeled<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            content()
        }
    }
}
