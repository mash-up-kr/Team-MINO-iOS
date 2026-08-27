import XCTest
import SwiftUI
@testable import DesignSystem

/// 슬롯별 `isEnabled` 계약 — 한 슬롯을 비활성으로 두어도 다른 슬롯은 그대로 활성이어야 한다.
///
/// 영역 전체에 `.disabled` 를 거는 방식으로 되돌아가면 두 슬롯이 함께 죽어 이 테스트가 깨진다.
final class MHActionAreaEnablementTests: XCTestCase {
    // neutral 배치는 가로 [alternative | main] 이고 폭 375·좌우 패딩 20·간격 12 라
    // 각 버튼은 약 161.5pt. 경계를 피해 안쪽만 잘라 비교한다.
    private static let alternativeSlot = CGRect(x: 25, y: 0, width: 150, height: 0)
    private static let mainSlot = CGRect(x: 200, y: 0, width: 150, height: 0)

    @MainActor
    private func render(mainEnabled: Bool, alternativeEnabled: Bool) throws -> UIImage {
        MHFontRegistrar.registerIfNeeded()
        let renderer = ImageRenderer(
            content: MHActionArea(
                variant: .neutral,
                main: .init("저장", isEnabled: mainEnabled) {},
                alternative: .init("지우기", isEnabled: alternativeEnabled) {},
                safeArea: false
            )
            .frame(width: 375)
        )
        renderer.scale = RenderScale.ink   // 픽셀 비교라 배율이 필요하다 — RenderScale 주석 참조
        return try XCTUnwrap(renderer.uiImage)
    }

    private func slice(_ image: UIImage, _ slot: CGRect) throws -> Data {
        let cgImage = try XCTUnwrap(image.cgImage)
        // slot 은 pt 좌표라 픽셀로 환산해 자른다.
        let rect = CGRect(x: slot.minX * RenderScale.ink, y: 0,
                          width: slot.width * RenderScale.ink, height: CGFloat(cgImage.height))
        let cropped = try XCTUnwrap(cgImage.cropping(to: rect))
        return try XCTUnwrap(UIImage(cgImage: cropped).pngData())
    }

    @MainActor
    func testDisablingMainLeavesAlternativeUntouched() throws {
        let bothEnabled = try render(mainEnabled: true, alternativeEnabled: true)
        let onlyMainDisabled = try render(mainEnabled: false, alternativeEnabled: true)

        XCTAssertEqual(
            try slice(bothEnabled, Self.alternativeSlot),
            try slice(onlyMainDisabled, Self.alternativeSlot),
            "main 을 비활성으로 두었는데 alternative 슬롯까지 함께 흐려졌다"
        )
    }

    @MainActor
    func testDisablingMainStillDimsMain() throws {
        let bothEnabled = try render(mainEnabled: true, alternativeEnabled: true)
        let onlyMainDisabled = try render(mainEnabled: false, alternativeEnabled: true)

        XCTAssertNotEqual(
            try slice(bothEnabled, Self.mainSlot),
            try slice(onlyMainDisabled, Self.mainSlot),
            "isEnabled: false 를 주었는데 main 슬롯이 활성과 똑같이 그려졌다"
        )
    }

    @MainActor
    func testDisablingAlternativeLeavesMainUntouched() throws {
        let bothEnabled = try render(mainEnabled: true, alternativeEnabled: true)
        let onlyAlternativeDisabled = try render(mainEnabled: true, alternativeEnabled: false)

        XCTAssertEqual(
            try slice(bothEnabled, Self.mainSlot),
            try slice(onlyAlternativeDisabled, Self.mainSlot),
            "alternative 를 비활성으로 두었는데 main 슬롯까지 함께 흐려졌다"
        )
        XCTAssertNotEqual(
            try slice(bothEnabled, Self.alternativeSlot),
            try slice(onlyAlternativeDisabled, Self.alternativeSlot),
            "isEnabled: false 를 주었는데 alternative 슬롯이 활성과 똑같이 그려졌다"
        )
    }
}
