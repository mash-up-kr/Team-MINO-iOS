import XCTest
import SwiftUI
import UIKit
@testable import DesignSystem

// 양식은 `MHLocationCardTests` 선례 — XCTest + ImageRenderer + MHFontRegistrar.registerIfNeeded() 선행.
// 렌더 테스트는 "렌더된다"(nil 아님)로 끝내지 않고 최소 한 개의 변별 단언(높이·폭·픽셀 차)을 둔다.
final class MHNotificationCellTests: XCTestCase {
    // T1 — 375 폭에서 셀 높이가 80(Figma `Frame 500` 실측).
    @MainActor
    func testHeightAt375Width() throws {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content:
            MHNotificationCell(title: "이미 저장해둔 곳이에요", subtitle: "연남동 스탠딩 커피",
                                time: "방금", thumbnail: .icon)
                .frame(width: 375))
        r.scale = 1
        let img = try XCTUnwrap(r.uiImage, "MHNotificationCell 렌더 실패")
        XCTAssertEqual(img.size.width, 375, accuracy: 1.0)
        XCTAssertEqual(img.size.height, 80, accuracy: 1.0)
    }

    // T2 — 제목·부제를 아주 길게 넣어도 높이는 T1 과 같다.
    // UX-007: 넘치면 줄바꿈이 아니라 말줄임이라(lineLimit(1) + .tail) 모든 행 높이가 같다.
    @MainActor
    func testHeightUnchangedWithLongText() throws {
        MHFontRegistrar.registerIfNeeded()
        let longTitle = String(repeating: "아주아주긴제목텍스트", count: 10)
        let longSubtitle = String(repeating: "아주아주긴부제텍스트", count: 10)
        let r = ImageRenderer(content:
            MHNotificationCell(title: longTitle, subtitle: longSubtitle,
                                time: "3시간 전", thumbnail: .icon)
                .frame(width: 375))
        r.scale = 1
        let img = try XCTUnwrap(r.uiImage, "긴 텍스트 셀 렌더 실패")
        XCTAssertEqual(img.size.width, 375, accuracy: 1.0)
        XCTAssertEqual(img.size.height, 80, accuracy: 1.0)
    }

    // T3 — `.place`(비정사각 테스트 이미지)가 `MHThumbnail` 크롭·클립을 실제로 거친다.
    // 정사각 단색 이미지로는 크롭이 빠지거나 클립 반경이 바뀌어도 통과해 계약을 못 붙잡는다
    // (좌우 절반을 다른 색으로 나눈 비정사각 이미지를 넣어, 정사각으로 크롭되며 중앙 픽셀이
    // 어느 한쪽 색으로 고정되는지 + 좌상단 코너가 클립으로 배경색인지를 함께 본다).
    @MainActor
    func testPlaceThumbnailIsCroppedSquareAndClipped() throws {
        MHFontRegistrar.registerIfNeeded()
        // 112×28 — 세로가 가로의 1/4. 정사각(56×56)으로 스케일-채움 크롭되면 원본의 세로 전체가
        // 다 들어가고 가로는 중앙 56pt만 남는다 — 좌우 절반 색이 다르므로 중앙(크롭 후 정중앙)은
        // 항상 오른쪽 절반 색(파랑)이어야 한다. 왜곡(비율 무시 resize)이면 이 보장이 깨진다.
        let splitImage = Self.splitColorImage(left: .systemRed, right: .systemBlue, size: CGSize(width: 112, height: 28))

        let r = ImageRenderer(content:
            MHNotificationCell(title: "제목", subtitle: "부제", time: "방금", thumbnail: .place(splitImage))
                .frame(width: 375))
        r.scale = 1
        let img = try XCTUnwrap(r.uiImage, ".place 렌더 실패")
        let cgImage = try XCTUnwrap(img.cgImage)

        // 셀 좌우 padding 20 + 썸네일 상하 padding 12 → 썸네일은 (20,12)~(76,68), 56×56.
        let thumbnailOrigin = CGPoint(x: 20, y: 12)
        let center = CGPoint(x: thumbnailOrigin.x + 28, y: thumbnailOrigin.y + 28)
        let centerColor = try XCTUnwrap(Self.pixelColor(cgImage, at: center))
        XCTAssertGreaterThan(centerColor.blue, centerColor.red,
                              "정사각 크롭 후 중앙 픽셀이 오른쪽(파랑) 절반이 아니다 — scaledToFill 크롭이 빠졌을 수 있다")

        // 클립(둥근 모서리) — 정사각 프레임의 좌상단 코너는 원 밖이라 배경(투명)이어야 한다.
        let corner = CGPoint(x: thumbnailOrigin.x + 1, y: thumbnailOrigin.y + 1)
        let cornerColor = try XCTUnwrap(Self.pixelColor(cgImage, at: corner))
        XCTAssertLessThan(cornerColor.alpha, 0.5,
                           "썸네일 좌상단 코너가 불투명하다 — 둥근 모서리 클립이 빠졌을 수 있다")
    }

    // T7 — 375 폭(실사용 폭)의 셀 안에서, 긴 시간 문구의 잉크 폭이 그 문구를 단독으로(잘릴 걱정 없이)
    // 그렸을 때의 자연 폭과 같다(=셀 안에서도 안 잘린다).
    //
    // 시간 자리를 `.frame(width: 48)` 로 고정하면(구현 이전 상태) `23시간 전` 은 말줄임표로 잘려
    // 실렌더 잉크 폭이 자연 폭보다 뚜렷이 좁아진다 — 이 차이로 잘림을 잡는다. (짧은 문구끼리의
    // x 좌표 비교로는 "잘렸어도 문구가 다르니 그림이 다르다"는 참-거짓 어느 쪽도 못 잡는 것을
    // 뮤테이션 테스트로 확인했다 — 자연 폭 대비 비교가 실제 계약이다.)
    @MainActor
    func testLongTimeTextInkWidthMatchesNaturalWidth() throws {
        MHFontRegistrar.registerIfNeeded()
        let longTime = "23시간 전"

        // 셀 375 폭 안에서 실제로 그려진 시간 영역의 잉크 폭.
        let cellRenderer = ImageRenderer(content:
            MHNotificationCell(title: "제목", subtitle: "부제", time: longTime, thumbnail: .icon)
                .frame(width: 375))
        cellRenderer.scale = RenderScale.ink   // 픽셀 스캔이라 배율이 필요하다 — RenderScale 주석 참조
        let cellImage = try XCTUnwrap(cellRenderer.uiImage, "셀 렌더 실패")
        let cellCGImage = try XCTUnwrap(cellImage.cgImage)
        // 시간 영역은 셀 우측 padding 20 안쪽, y=12~28(높이 16) 부근. 넉넉히 우측 115pt 를 본다.
        // 좌표는 pt 로 적고 배율을 곱해 픽셀로 환산한다. 폭도 pt 로 되돌려 비교한다.
        let s = RenderScale.inkInt
        let actualWidth = try XCTUnwrap(
            Self.inkWidth(cellCGImage, xRange: 260 * s..<355 * s, yRange: 10 * s..<30 * s),
            "셀 안에서 시간 잉크 픽셀을 찾지 못했다"
        ) / RenderScale.ink

        // 잘릴 걱정이 없는 단독 렌더의 자연 잉크 폭 — 같은 `Text` + 같은 타이포 토큰을 그대로 쓴다.
        let naturalRenderer = ImageRenderer(content:
            Text(longTime).mhTypography(.caption1Regular).foregroundStyle(.mhLabelAlternative)
                .fixedSize())
        naturalRenderer.scale = RenderScale.ink
        let naturalImage = try XCTUnwrap(naturalRenderer.uiImage, "단독 렌더 실패")
        let naturalCGImage = try XCTUnwrap(naturalImage.cgImage)
        let naturalWidth = try XCTUnwrap(
            Self.inkWidth(naturalCGImage, xRange: 0..<naturalCGImage.width, yRange: 0..<naturalCGImage.height),
            "단독 렌더에서 잉크 픽셀을 찾지 못했다"
        ) / RenderScale.ink

        XCTAssertEqual(
            actualWidth, naturalWidth, accuracy: 3,
            "375 폭 셀 안의 시간 잉크 폭(\(actualWidth))이 자연 폭(\(naturalWidth))보다 좁다 — 잘렸을 가능성"
        )
    }

    // MARK: - 테스트 이미지·픽셀 헬퍼

    private static func splitColorImage(left: UIColor, right: UIColor, size: CGSize) -> Image {
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { _ in
            left.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            right.setFill()
            UIRectFill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
        }
        return Image(uiImage: uiImage)
    }

    private struct PixelColor { let red: CGFloat; let blue: CGFloat; let alpha: CGFloat }

    /// RGBA8 premultiplied(ImageRenderer/UIGraphicsImageRenderer 표준 출력 포맷) 픽셀 버퍼 접근의
    /// 단일 지점 — `pixelColor`·`inkWidth` 둘 다 이 오프셋 계산만 쓴다.
    private static func pixelOffset(_ cgImage: CGImage, x: Int, y: Int, data: CFData) -> Int? {
        guard x >= 0, y >= 0, x < cgImage.width, y < cgImage.height else { return nil }
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let offset = y * cgImage.bytesPerRow + x * bytesPerPixel
        guard offset + 3 < CFDataGetLength(data) else { return nil }
        return offset
    }

    private static func pixelColor(_ cgImage: CGImage, at point: CGPoint) -> PixelColor? {
        guard let data = cgImage.dataProvider?.data, let ptr = CFDataGetBytePtr(data),
              let offset = pixelOffset(cgImage, x: Int(point.x), y: Int(point.y), data: data) else { return nil }
        return PixelColor(
            red: CGFloat(ptr[offset]) / 255,
            blue: CGFloat(ptr[offset + 2]) / 255,
            alpha: CGFloat(ptr[offset + 3]) / 255
        )
    }

    /// `xRange`(왼→오)·`yRange` 안에서 알파가 있는(비투명) 픽셀의 가로 폭(가장 오른쪽 x − 가장
    /// 왼쪽 x + 1). 잉크가 하나도 없으면 `nil`.
    private static func inkWidth(_ cgImage: CGImage, xRange: Range<Int>, yRange: Range<Int>) -> CGFloat? {
        guard let data = cgImage.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        var minX: Int?
        var maxX: Int?
        for x in xRange {
            for y in yRange {
                guard let offset = pixelOffset(cgImage, x: x, y: y, data: data) else { continue }
                let alpha = CGFloat(ptr[offset + 3]) / 255
                if alpha > 0.3 {
                    minX = min(minX ?? x, x)
                    maxX = max(maxX ?? x, x)
                    break
                }
            }
        }
        guard let minX, let maxX else { return nil }
        return CGFloat(maxX - minX + 1)
    }
}
