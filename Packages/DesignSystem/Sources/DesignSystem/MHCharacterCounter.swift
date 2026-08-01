import SwiftUI

// MARK: - Character Counter

/// 입력 글자수/최대치를 `현재/최대` 로 보여주는 카운터. Figma TextArea `characterCounter`.
///
/// TextArea 하단 바(leading/trailing)에 넣어 쓴다. 최대치를 넘으면(`overflow`) 색이 에러색으로 바뀐다.
///
/// ```swift
/// MHCharacterCounter(count: text.count, limit: 2000)   // "6/2000"
/// ```
public struct MHCharacterCounter: View {
    private let count: Int
    private let limit: Int

    @Environment(\.isEnabled) private var isEnabled

    public init(count: Int, limit: Int) {
        self.count = count
        self.limit = limit
    }

    private var isOverflow: Bool { count > limit }
    // 현재 수 색: 비활성=Label/Disable, 초과=Status/Negative, 그 외=Label/Alternative.
    private var countColor: Color {
        if !isEnabled { return .mhLabelDisable }
        return isOverflow ? .mhStatusNegative : .mhLabelAlternative
    }
    // '/최대' 색: 비활성=Label/Disable, 그 외 Label/Alternative(초과여도 회색 유지).
    private var suffixColor: Color { isEnabled ? .mhLabelAlternative : .mhLabelDisable }

    public var body: some View {
        // Figma 실측: 초과 시 '현재 수'만 Status/Negative, '/최대' 는 Label/Alternative 유지. 전체 74% 불투명.
        // 비활성(부모 TextArea .disabled) 시 둘 다 Label/Disable(Figma 135822). verbatim: 로케일 쉼표 방지.
        HStack(spacing: 0) {
            Text(verbatim: "\(count)").foregroundStyle(countColor)
            Text(verbatim: "/\(limit)").foregroundStyle(suffixColor)
        }
        .mhTypography(.label2Medium)
        .monospacedDigit()
        .opacity(0.74)                 // Figma Wrapper opacity/74
        .padding(.horizontal, 4)       // Figma Wrapper px-4
    }
}
