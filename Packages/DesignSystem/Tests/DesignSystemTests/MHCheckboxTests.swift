import XCTest
import SwiftUI
@testable import DesignSystem

final class MHCheckboxTests: XCTestCase {
    // 박스 크기: Normal 18, Small 16.
    @MainActor
    func testBoxSize() throws {
        MHFontRegistrar.registerIfNeeded()
        func side(_ size: MHCheckboxSize) -> CGFloat {
            let r = ImageRenderer(content: MHCheckbox(state: .unchecked, size: size)); r.scale = 1
            return r.uiImage?.size.width ?? 0
        }
        XCTAssertEqual(side(.normal), 18, accuracy: 0.5)
        XCTAssertEqual(side(.small), 16, accuracy: 0.5)
    }

    @MainActor
    func testGalleryRenders() throws {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(content: Gallery())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "MHCheckbox 갤러리 렌더 실패")
        XCTAssertGreaterThan(img.size.width, 0)

        let dir = ProcessInfo.processInfo.environment["SNAP_DIR"]
            ?? "/private/tmp/claude-502/-Users-kim-yubeen-dev-Mash-Up-16--Team-MINO-iOS/35bb484e-e2f3-437f-9f0f-7d49f1a3e101/scratchpad"
        if let data = img.pngData() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("mhcheckbox_gallery.png")
            try? data.write(to: url)
            print("SNAPSHOT_WRITTEN:\(url.path)")
        }
    }
}

// Figma 매트릭스: state(unchecked/checked/indeterminate) × size(normal/small) × enabled/disabled.
private struct Gallery: View {
    private let states: [MHCheckboxState] = [.unchecked, .checked, .indeterminate]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            row("Normal · enabled", .normal, false)
            row("Normal · disabled", .normal, true)
            row("Small · enabled", .small, false)
            row("Small · disabled", .small, true)
        }
        .padding(24)
        .background(Color.white)
    }

    private func row(_ label: String, _ size: MHCheckboxSize, _ disabled: Bool) -> some View {
        HStack(spacing: 24) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            ForEach(states, id: \.self) { s in
                MHCheckbox(state: s, size: size) { }.disabled(disabled)
            }
        }
    }
}

extension MHCheckboxState: Hashable {}
