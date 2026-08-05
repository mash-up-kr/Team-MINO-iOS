import XCTest
import SwiftUI
@testable import DesignSystem

final class MHAvatarGroupSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHAvatarGroup 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/8d4054e0-f43f-4405-b167-77aae83b9180/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhavatargroup_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // 겹침 레이아웃 폭이 Figma와 일치하는지(XSmall 96 / Small 128, 아바타 5개).
    @MainActor
    func testGroupWidthMatchesFigma() throws {
        func width(_ size: MHAvatarGroupSize) -> CGFloat {
            let r = ImageRenderer(content:
                MHAvatarGroup(Array(repeating: Image?.none, count: 5), variant: .person, size: size))
            r.scale = 1
            return r.uiImage?.size.width ?? 0
        }
        XCTAssertEqual(width(.xSmall), 96, accuracy: 0.5)   // 4×18 + 24
        XCTAssertEqual(width(.small), 128, accuracy: 0.5)   // 4×24 + 32
    }
}

private struct Gallery: View {
    private let five = Array(repeating: Image?.none, count: 5)
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            label("variant · xSmall")
            HStack(spacing: 24) {
                MHAvatarGroup(five, variant: .person, size: .xSmall)
                MHAvatarGroup(five, variant: .company, size: .xSmall)
                MHAvatarGroup(five, variant: .academy, size: .xSmall)
            }
            label("size · xSmall / small")
            HStack(spacing: 24) {
                MHAvatarGroup(five, variant: .person, size: .xSmall)
                MHAvatarGroup(five, variant: .person, size: .small)
            }
            label("trailingContent · 외 N명")
            VStack(alignment: .leading, spacing: 12) {
                MHAvatarGroup(five, variant: .person, size: .xSmall, remaining: 0)
                MHAvatarGroup(five, variant: .person, size: .small, remaining: 12)
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
