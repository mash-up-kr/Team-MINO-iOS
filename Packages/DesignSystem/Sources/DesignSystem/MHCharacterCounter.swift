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
        // verbatim: SwiftUI Text 보간은 정수에 로케일 자릿수 구분(쉼표)을 넣어 "2,000" 이 되므로 방지("2000").
        Text(verbatim: "\(count)/\(limit)")
            .mhTypography(.label2Medium)
            // 기본 Label/Alternative @ 74%, 초과 시 Status/Negative(강조).
            .foregroundStyle(isOverflow ? Color.mhStatusNegative : Color.mhLabelAlternative.opacity(0.74))
            .padding(.horizontal, 4)   // Figma Wrapper px-4
            .monospacedDigit()          // 숫자 폭 흔들림 방지
    }
}
