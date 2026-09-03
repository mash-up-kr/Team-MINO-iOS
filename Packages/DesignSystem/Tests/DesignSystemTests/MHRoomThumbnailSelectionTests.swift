import XCTest
import SwiftUI
@testable import DesignSystem

/// ``MHRoomThumbnail`` 의 선택 표시(딤 + 체크) 검증.
/// Figma `Room Thumbnail` property2="select"(node 3251-202525): 검정 40% 딤 + 흰 체크 28pt(70pt 기준).
///
/// > 딤만 여기서 검증한다. `ImageRenderer` 는 템플릿 SVG 아이콘(`Image(MHIcon.checkThick)`)을
/// > 래스터화하지 않아 — 렌더 결과의 모든 픽셀이 정확히 원본의 60%, 즉 딤만 남는다 — 체크 글리프를
/// > 픽셀로 단언할 수 없다. 체크 자체는 시뮬레이터 육안 확인,
/// > 에셋 존재는 `MHIconTests.testAllIconAssetsResolve` 가 담당한다.
final class MHRoomThumbnailSelectionTests: XCTestCase {
    private let size = 70

    @MainActor
    private func render(isSelected: Bool) throws -> UIImage {
        let renderer = ImageRenderer(
            content: MHRoomThumbnail(color: .cyan, size: CGFloat(size), isSelected: isSelected)
        )
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage, "MHRoomThumbnail 렌더 실패")
    }

    /// RGBA8 픽셀 버퍼로 펼친다. 인덱스 = (y * width + x) * 4.
    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var buffer = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &buffer,
            width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return buffer
    }

    /// 체크 글리프가 놓이는 중앙 28pt 정사각(70pt 기준 0.4배) 바깥인지 — 딤 비율 검사에서 제외한다.
    private func isOutsideCheckBox(x: Int, y: Int) -> Bool {
        let half = Double(size) * 0.4 / 2
        let center = Double(size) / 2
        return abs(Double(x) - center) > half || abs(Double(y) - center) > half
    }

    /// 딤은 검정 40% — 체크 영역 밖의 모든 불투명 픽셀이 원본의 60% 밝기가 되어야 한다.
    /// (Figma 실측 대조: cyan/95 #DEFAFF → 딤 적용 시 (133,150,153))
    @MainActor
    func testSelectedAppliesFortyPercentBlackDim() throws {
        let plain = try pixels(render(isSelected: false))
        let selected = try pixels(render(isSelected: true))

        var compared = 0
        var maxDelta = 0.0
        for y in 0..<size where true {
            for x in 0..<size where isOutsideCheckBox(x: x, y: y) {
                let i = (y * size + x) * 4
                guard plain[i + 3] == 255, selected[i + 3] == 255 else { continue }   // 라운드 코너 밖 제외
                compared += 1
                for channel in 0..<3 {
                    let expected = Double(plain[i + channel]) * 0.6
                    maxDelta = max(maxDelta, abs(Double(selected[i + channel]) - expected))
                }
            }
        }

        XCTAssertGreaterThan(compared, 1_000, "비교한 불투명 픽셀이 너무 적어 검증이 성립하지 않는다")
        XCTAssertLessThanOrEqual(maxDelta, 3.0, "딤이 검정 40%(원본의 60% 밝기)가 아니다 — 최대 오차 \(maxDelta)")
    }

    /// 선택이 아니면 오버레이가 전혀 없어야 한다 — 기본 생성자와 바이트 단위로 같다.
    @MainActor
    func testUnselectedIsIdenticalToDefault() throws {
        let byFlag = try render(isSelected: false).pngData()
        let renderer = ImageRenderer(content: MHRoomThumbnail(color: .cyan, size: CGFloat(size)))
        renderer.scale = 1
        let byDefault = try XCTUnwrap(renderer.uiImage).pngData()

        XCTAssertEqual(byFlag, byDefault, "isSelected: false 인데 기본 렌더와 다르다")
    }
}
