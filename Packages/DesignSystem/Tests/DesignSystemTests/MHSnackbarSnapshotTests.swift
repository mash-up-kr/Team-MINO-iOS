import XCTest
import SwiftUI
@testable import DesignSystem

final class MHSnackbarSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHSnackbar 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/8d4054e0-f43f-4405-b167-77aae83b9180/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhsnackbar_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }

    // 단일 라인 스낵바 높이가 Figma(48pt)와 일치하는지.
    @MainActor
    func testSingleLineHeightMatchesFigma() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHSnackbar(title: "메시지에 마침표를 찍어요.", actionTitle: "텍스트") {}.frame(width: 384))
        r.scale = 1
        let h = try XCTUnwrap(r.uiImage).size.height
        XCTAssertEqual(h, 48, accuracy: 1.5)   // Figma Snackbar/Snackbar 단일 라인 = 48pt (2862:178010 · 1672:73661 실측)
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("title only (기본)")
            snack { MHSnackbar(title: "메시지에 마침표를 찍어요.", actionTitle: "텍스트") {} }

            label("title + description")
            snack { MHSnackbar(title: "메시지에 마침표를 찍어요.", description: "설명은 필요할 때만 써요.", actionTitle: "텍스트") {} }

            label("description only (heading=false)")
            snack { MHSnackbar(description: "메시지가 두 줄 이상 길어지는 경우 예외적으로도 사용해요.", actionTitle: "텍스트") {} }

            label("icon")
            snack { MHSnackbar(title: "메시지에 마침표를 찍어요.", icon: .circleCheck, actionTitle: "텍스트") {} }

            label("close button")
            snack { MHSnackbar(title: "메시지에 마침표를 찍어요.", actionTitle: "텍스트", action: {}, onClose: {}) }

            label("full (icon + description + close)")
            snack { MHSnackbar(title: "메시지에 마침표를 찍어요.", description: "설명은 필요할 때만 써요.", icon: .circleCheck, actionTitle: "텍스트", action: {}, onClose: {}) }
        }
        .padding(24)
        .frame(width: 335 + 48, alignment: .leading)
        .background(Color(white: 0.93))
    }

    private func snack<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content().frame(width: 335, alignment: .leading)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
