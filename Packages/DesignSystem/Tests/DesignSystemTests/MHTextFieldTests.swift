import XCTest
import SwiftUI
@testable import DesignSystem

final class MHTextFieldTests: XCTestCase {
    // Figma 실측 고정값(패딩·높이·radius·아이콘·간격).
    func testMetricsMatchFigma() {
        XCTAssertEqual(MHTextFieldMetric.boxHeight, 48)
        XCTAssertEqual(MHTextFieldMetric.contentMinHeight, 24)
        XCTAssertEqual(MHTextFieldMetric.contentPadding, 12)
        XCTAssertEqual(MHTextFieldMetric.cornerRadius, 12)
        XCTAssertEqual(MHTextFieldMetric.iconSize, 22)
        XCTAssertEqual(MHTextFieldMetric.contentGap, 8)
        XCTAssertEqual(MHTextFieldMetric.textHPadding, 4)
        XCTAssertEqual(MHTextFieldMetric.stackSpacing, 8)
        XCTAssertEqual(MHTextFieldMetric.headingGap, 4)
        XCTAssertEqual(MHTextFieldMetric.inputFontSize, 16)
    }

    // 테두리 두께: 포커스면 2px(상태 무관 — 에러 포커스도 2px), 그 외 1px.
    func testBorderWidth() {
        XCTAssertEqual(spec(.normal, enabled: true, focused: true).borderWidth, 2)
        XCTAssertEqual(spec(.positive, enabled: true, focused: true).borderWidth, 2)
        XCTAssertEqual(spec(.negative, enabled: true, focused: true).borderWidth, 2)  // 에러 포커스도 2px
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).borderWidth, 1)
        XCTAssertEqual(spec(.negative, enabled: true, focused: false).borderWidth, 1)
        XCTAssertEqual(spec(.normal, enabled: false, focused: true).borderWidth, 1)   // 비활성 우선
    }

    // 테두리 색(Figma status 매트릭스): 비활성 > 에러 > 포커스 > 기본. 포커스는 불투명도만 43% 로.
    func testBorderColor() {
        XCTAssertEqual(spec(.negative, enabled: false, focused: true).borderColor, .mhLineNormalAlternative) // 비활성
        XCTAssertEqual(spec(.negative, enabled: true, focused: false).borderColor, Color.mhStatusNegative.opacity(0.28)) // 에러 기본
        XCTAssertEqual(spec(.negative, enabled: true, focused: true).borderColor, Color.mhStatusNegative.opacity(0.43))  // 에러 포커스
        XCTAssertEqual(spec(.normal, enabled: true, focused: true).borderColor, Color.mhPrimaryNormal.opacity(0.43)) // 포커스
        XCTAssertEqual(spec(.positive, enabled: true, focused: true).borderColor, Color.mhPrimaryNormal.opacity(0.43)) // 성공 포커스=Primary
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).borderColor, .mhLineNormalNeutral) // 기본
        XCTAssertEqual(spec(.positive, enabled: true, focused: false).borderColor, .mhLineNormalNeutral) // 성공=기본 테두리
    }

    // trailing 슬롯(Figma status 매트릭스 8셀): 포커스+입력값=clear, 그 외=상태 아이콘.
    func testTrailing() {
        // 포커스 + 입력값 → clear (성공·에러도 clear 로 대체)
        XCTAssertEqual(spec(.normal, enabled: true, focused: true).trailing(hasText: true, showsClearButton: true), .clear)
        XCTAssertEqual(spec(.positive, enabled: true, focused: true).trailing(hasText: true, showsClearButton: true), .clear)
        XCTAssertEqual(spec(.negative, enabled: true, focused: true).trailing(hasText: true, showsClearButton: true), .clear)
        // 포커스 + 빈 값 → 상태 아이콘(clear 아님)
        XCTAssertEqual(spec(.negative, enabled: true, focused: true).trailing(hasText: false, showsClearButton: true), .negativeIcon)
        XCTAssertEqual(spec(.normal, enabled: true, focused: true).trailing(hasText: false, showsClearButton: true), MHTextFieldTrailing.none)
        // 비포커스 → 상태 아이콘(입력값 유무 무관)
        XCTAssertEqual(spec(.positive, enabled: true, focused: false).trailing(hasText: true, showsClearButton: true), .positiveIcon)
        XCTAssertEqual(spec(.negative, enabled: true, focused: false).trailing(hasText: true, showsClearButton: true), .negativeIcon)
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).trailing(hasText: true, showsClearButton: true), MHTextFieldTrailing.none)
        // showsClearButton=false → 포커스+입력값이어도 clear 안 뜸
        XCTAssertEqual(spec(.normal, enabled: true, focused: true).trailing(hasText: true, showsClearButton: false), MHTextFieldTrailing.none)
    }

    // 배경: 활성=Transparent/Normal, 비활성=Interaction/Disable.
    func testBackgroundColor() {
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).backgroundColor, .mhBackgroundTransparentNormal)
        XCTAssertEqual(spec(.normal, enabled: false, focused: false).backgroundColor, .mhInteractionDisable)
    }

    // 입력 텍스트 색(Figma disabled 행 실측): 값=Normal→Alternative, placeholder=Assistive→Disable.
    func testTextColors() {
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).valueTextColor, .mhLabelNormal)
        XCTAssertEqual(spec(.normal, enabled: false, focused: false).valueTextColor, .mhLabelAlternative)   // 비활성 값
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).placeholderColor, .mhLabelAssistive)
        XCTAssertEqual(spec(.normal, enabled: false, focused: false).placeholderColor, .mhLabelDisable)     // 비활성 placeholder
    }

    // description 색: 에러만 빨강, 그 외 Label/Alternative(성공도 회색).
    func testDescriptionColor() {
        XCTAssertEqual(spec(.negative, enabled: true, focused: false).descriptionColor, .mhStatusNegative)
        XCTAssertEqual(spec(.positive, enabled: true, focused: false).descriptionColor, .mhLabelAlternative)
        XCTAssertEqual(spec(.normal, enabled: true, focused: false).descriptionColor, .mhLabelAlternative)
    }

    // 실제 렌더 높이: 라벨·도움말 없는 단일 박스는 Figma 고정 높이 48.
    @MainActor
    func testRenderedBoxHeightMatchesFigma() {
        MHFontRegistrar.registerIfNeeded()
        let r = ImageRenderer(content: MHTextField("텍스트를 입력해 주세요.", text: .constant("")).frame(width: 335))
        r.scale = 1
        XCTAssertEqual(r.uiImage?.size.height ?? 0, 48, accuracy: 0.5)
    }

    private func spec(_ status: MHTextFieldStatus, enabled: Bool, focused: Bool) -> MHTextFieldSpec {
        MHTextFieldSpec(status: status, isEnabled: enabled, isFocused: focused)
    }
}
