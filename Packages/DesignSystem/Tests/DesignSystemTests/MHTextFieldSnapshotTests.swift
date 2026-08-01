import XCTest
import SwiftUI
@testable import DesignSystem

// 렌더 스모크 + (SNAP_DIR 지정 시) 갤러리 PNG 산출. 포커스(2px) 는 정적 렌더로 못 잡아 단위테스트로 검증.
final class MHTextFieldSnapshotTests: XCTestCase {
    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHTextField 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        // 로컬 육안 검증용: SNAP_DIR 환경변수가 있을 때만 파일로 떨군다(CI 무해).
        // 다만 ImageRenderer 는 TextField(UIKit) 와 .mhShadow(UIViewRepresentable) 를 못 그려
        // 입력부가 placeholder 로 뜬다 — 실제 육안 검증은 시뮬레이터 실행으로 한다. 이 테스트는 렌더 스모크.
        if let dir = ProcessInfo.processInfo.environment["SNAP_DIR"], let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhtextfield_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

private struct Gallery: View {
    var body: some View {
        // Figma status 열(normal / positive / negative)을 3열로 재현.
        HStack(alignment: .top, spacing: 24) {
            column("normal", status: .normal)
            column("positive", status: .positive)
            column("negative", status: .negative)
        }
        .padding(24)
        .background(Color.white)
    }

    private func column(_ label: String, status: MHTextFieldStatus) -> some View {
        let desc = status == .negative ? "에러 메시지를 나타내요."
                 : status == .positive ? "성공 메시지를 나타내요."
                 : "메시지에 마침표를 찍어요."
        return VStack(alignment: .leading, spacing: 20) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            // 빈 값(placeholder)
            MHTextField("텍스트를 입력해 주세요.", text: .constant(""),
                        heading: "주제", description: desc, status: status)
            // 입력 값 + trailing(성공/에러 아이콘 또는 clear)
            MHTextField("텍스트를 입력해 주세요.", text: .constant("값"),
                        heading: "주제", description: desc, status: status)
            // 필수(*) + leading 아이콘
            MHTextField("텍스트를 입력해 주세요.", text: .constant("값"),
                        heading: "주제", isRequired: true, description: desc,
                        status: status, leadingIcon: .search)
        }
        .frame(width: 335)
    }
}
