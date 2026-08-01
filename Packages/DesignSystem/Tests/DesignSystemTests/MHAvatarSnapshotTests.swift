import XCTest
import SwiftUI
@testable import DesignSystem

final class MHAvatarSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let sample = Image(uiImage: try XCTUnwrap(Self.sampleImage()))
        let renderer = ImageRenderer(content: Gallery(sample: sample))
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHAvatar 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/1d2ce843-5ebb-4a15-94d3-23177ec7a631/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhavatar_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    @MainActor static func sampleImage() -> UIImage? {
        let r = ImageRenderer(content:
            ZStack {
                LinearGradient(colors: [.blue, .teal, .green], startPoint: .top, endPoint: .bottom)
                Image(systemName: "person.fill").font(.system(size: 80)).foregroundStyle(.white)
            }.frame(width: 200, height: 200))
        r.scale = 2
        return r.uiImage
    }
}

private struct Gallery: View {
    let sample: Image
    private let sizes: [CGFloat] = [24, 32, 40, 48, 56]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row("person · 이미지", .person, image: true)
            row("person · placeholder", .person, image: false)
            row("company · 이미지 / placeholder(둥근 사각)", .company, image: true, showBothPlaceholder: true)
            row("academy · placeholder", .academy, image: false)
            HStack(spacing: 16) {
                Text("badge / press").font(.system(size: 11)).foregroundStyle(.secondary)
                MHAvatar(sample, size: 48) {
                    Text("N").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .overlay(Capsule().stroke(.white, lineWidth: 2))
                }
                MHAvatar(sample, size: 48) {
                    Circle().fill(.red).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func row(_ label: String, _ variant: MHAvatarVariant, image: Bool, showBothPlaceholder: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(sizes, id: \.self) { s in
                    MHAvatar(image ? sample : nil, variant: variant, size: s)
                }
                if showBothPlaceholder {
                    MHAvatar(nil, variant: variant, size: 40)
                }
            }
        }
    }
}
