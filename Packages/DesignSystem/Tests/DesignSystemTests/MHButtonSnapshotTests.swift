import XCTest
import SwiftUI
@testable import DesignSystem

// 렌더 스모크 + (SNAP_DIR 지정 시) 갤러리 PNG 산출. 크래시 없이 그려지는지 회귀 검증.
final class MHButtonSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHButton 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        // 로컬 육안 검증용: SNAP_DIR 환경변수가 있을 때만 파일로 떨군다(CI 무해).
        if let dir = ProcessInfo.processInfo.environment["SNAP_DIR"], let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhbutton_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            row("Solid / Primary", variant: .solid, color: .primary)
            row("Solid / Assistive", variant: .solid, color: .assistive)
            row("Outlined / Primary", variant: .outlined, color: .primary)
            row("Outlined / Assistive", variant: .outlined, color: .assistive)
            HStack(spacing: 12) {
                MHButton("담기", leadingIcon: .plus) {}
                MHButton("공유", variant: .outlined, trailingIcon: .share) {}
                MHButton(icon: .setting) {}
                MHButton(icon: .star, variant: .outlined, color: .assistive) {}
            }
            HStack(spacing: 12) {
                MHButton("메인 액션") {}.disabled(true)
                MHButton("전송", isLoading: true) {}
                MHButton("확인", variant: .outlined) {}.disabled(true)
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private func row(_ label: String, variant: MHButtonVariant, color: MHButtonColor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 12) {
                MHButton("Large", variant: variant, color: color, size: .large) {}
                MHButton("Medium", variant: variant, color: color, size: .medium) {}
                MHButton("Small", variant: variant, color: color, size: .small) {}
            }
        }
    }
}
