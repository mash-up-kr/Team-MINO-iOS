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

    public init(count: Int, limit: Int) {
        self.count = count
        self.limit = limit
    }

    private var isOverflow: Bool { count > limit }

    public var body: some View {
        // Figma 실측: 초과 시 '현재 수'만 Status/Negative, '/최대' 는 Label/Alternative 유지. 전체 74% 불투명.
        // verbatim: Text 보간이 정수에 로케일 쉼표를 넣는 것("2,000") 방지.
        HStack(spacing: 0) {
            Text(verbatim: "\(count)")
                .foregroundStyle(isOverflow ? Color.mhStatusNegative : Color.mhLabelAlternative)
            Text(verbatim: "/\(limit)")
                .foregroundStyle(Color.mhLabelAlternative)
        }
        .mhTypography(.label2Medium)
        .monospacedDigit()
        .opacity(0.74)                 // Figma Wrapper opacity/74
        .padding(.horizontal, 4)       // Figma Wrapper px-4
    }
}
