import XCTest
import SwiftUI
@testable import DesignSystem

final class MHTextAreaTests: XCTestCase {
    // Figma 실측 고정값.
    func testMetrics() {
        XCTAssertEqual(MHTextAreaMetric.lineHeight, 26)      // 개발코멘트: 한 줄 26px
        XCTAssertEqual(MHTextAreaMetric.contentPadding, 12)
        XCTAssertEqual(MHTextAreaMetric.cornerRadius, 12)
        XCTAssertEqual(MHTextAreaMetric.contentGap, 12)
        XCTAssertEqual(MHTextAreaMetric.bottomGap, 16)
        XCTAssertEqual(MHTextAreaMetric.inputFontSize, 16)
    }

    // resize 별 최소/최대 높이(줄 × 26).
    func testResizeHeights() {
        XCTAssertEqual(MHTextAreaResize.normal(minLines: 3).minHeight, 78)
        XCTAssertNil(MHTextAreaResize.normal(minLines: 3).maxHeight)              // 무한 성장
        XCTAssertEqual(MHTextAreaResize.limit(minLines: 2, maxLines: 5).minHeight, 52)
        XCTAssertEqual(MHTextAreaResize.limit(minLines: 2, maxLines: 5).maxHeight, 130)
        XCTAssertEqual(MHTextAreaResize.fixed(lines: 4).minHeight, 104)
        XCTAssertEqual(MHTextAreaResize.fixed(lines: 4).maxHeight, 104)           // 고정
    }

    // 테두리(TextField 와 동일 규칙, positive 없음): 비활성 > 에러 > 포커스 > 기본.
    func testBorder() {
        XCTAssertEqual(spec(.normal, true, false).borderColor, .mhLineNormalNeutral)
        XCTAssertEqual(spec(.normal, true, true).borderColor, Color.mhPrimaryNormal.opacity(0.43))
        XCTAssertEqual(spec(.negative, true, false).borderColor, Color.mhStatusNegative.opacity(0.28))
        XCTAssertEqual(spec(.negative, true, true).borderColor, Color.mhStatusNegative.opacity(0.43))
        XCTAssertEqual(spec(.normal, false, true).borderColor, .mhLineNormalNeutral)   // TextArea 비활성=Neutral
        XCTAssertEqual(spec(.normal, true, true).borderWidth, 2)
        XCTAssertEqual(spec(.negative, true, true).borderWidth, 2)
        XCTAssertEqual(spec(.normal, true, false).borderWidth, 1)
    }

    // 텍스트·설명 색.
    func testColors() {
        XCTAssertEqual(spec(.normal, true, false).valueTextColor, .mhLabelNormal)
        XCTAssertEqual(spec(.normal, false, false).valueTextColor, .mhLabelAlternative)
        XCTAssertEqual(spec(.normal, true, false).placeholderColor, .mhLabelAssistive)
        XCTAssertEqual(spec(.normal, false, false).placeholderColor, .mhLabelDisable)
        XCTAssertEqual(spec(.negative, true, false).descriptionColor, .mhStatusNegative)
        XCTAssertEqual(spec(.normal, true, false).descriptionColor, .mhLabelAlternative)
        XCTAssertEqual(spec(.normal, false, false).backgroundColor, .mhInteractionDisable)
    }

    // MHTextButton 색: primary=Primary/Normal, assistive=Label/Alternative, 비활성=Label/Disable.
    func testTextButton() {
        XCTAssertEqual(MHTextButtonVariant.primary.foreground(isEnabled: true), .mhPrimaryNormal)
        XCTAssertEqual(MHTextButtonVariant.assistive.foreground(isEnabled: true), .mhLabelAlternative)
        XCTAssertEqual(MHTextButtonVariant.primary.foreground(isEnabled: false), .mhLabelDisable)
    }

    private func spec(_ s: MHTextAreaStatus, _ enabled: Bool, _ focused: Bool) -> MHTextAreaSpec {
        MHTextAreaSpec(status: s, isEnabled: enabled, isFocused: focused)
    }
}
