import XCTest
import SwiftUI
@testable import DesignSystem

final class MHActionAreaSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThan(img.size.width, 0)
        if let dir = ProcessInfo.processInfo.environment["SNAP_DIR"], let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhactionarea_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

private struct Gallery: View {
    var body: some View {
        VStack(spacing: 24) {
            labeled("strong (main+alt+sub)") {
                MHActionArea(variant: .strong,
                             main: .init("메인 액션") {},
                             alternative: .init("대체 액션") {},
                             sub: .init("보조 액션") {},
                             safeArea: false)
            }
            labeled("neutral (sub+alt+main)") {
                MHActionArea(variant: .neutral,
                             main: .init("메인") {},
                             alternative: .init("대체") {},
                             sub: .init("보조") {},
                             safeArea: false)
            }
            labeled("cancel") {
                MHActionArea(variant: .cancel, main: .init("확인") {}, safeArea: false)
            }
            labeled("strong + divider") {
                MHActionArea(variant: .strong, main: .init("메인 액션") {}, divider: true, safeArea: false)
            }
            labeled("caption") {
                MHActionArea(main: .init("메인 액션") {},
                             caption: "필요한 경우 설명을 덧붙입니다.", safeArea: false)
            }
            labeled("extra: Summary") {
                MHActionArea(main: .init("결제하기") {}, safeArea: false) {
                    MHActionAreaSummary(label: "결제 금액", value: "12,000원")
                }
            }
            labeled("extra: Information") {
                MHActionArea(main: .init("확인") {}, safeArea: false) {
                    MHActionAreaInformation(heading: "헤딩", description: "필요한 경우 설명을 덧붙입니다.")
                }
            }
            labeled("extra: Checkbox") {
                MHActionArea(main: .init("동의하고 계속") {}, safeArea: false) {
                    MHActionAreaCheckbox("약관에 동의합니다", isOn: .constant(true))
                }
            }
            labeled("extra: Chips") {
                MHActionArea(main: .init("적용") {}, safeArea: false) {
                    MHActionAreaChips(["텍스트", "텍스트", "텍스트"])
                }
            }
        }
        .frame(width: 400)
        .padding(.vertical, 16)
        .background(Color.mhBackgroundNormalNormal)
    }

    private func labeled<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.leading, 20)
            content().background(Color.mhBackgroundNormalAlternative)
        }
    }
}
