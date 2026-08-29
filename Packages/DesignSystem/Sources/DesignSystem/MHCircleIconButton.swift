import SwiftUI

/// Figma `Button/Icon/Outlined` — 40pt 정원 + 1px 테두리에 아이콘 하나.
///
/// ``MHButton``의 아이콘 전용 형태는 정사각이라 이 원형을 대신하지 못한다. 시트 헤더의
/// 닫기·더보기 자리가 모두 이 모양이라 컴포넌트로 둔다.
///
/// ```swift
/// MHCircleIconButton(icon: .close, accessibilityLabel: "닫기") { dismiss() }
/// ```
public struct MHCircleIconButton: View {
    private let icon: MHIcon
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(icon: MHIcon, accessibilityLabel: String, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.mhLabelNormal)
                .frame(width: 40, height: 40)
                .overlay { Circle().strokeBorder(.mhLineNormalNeutral, lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    HStack(spacing: 12) {
        MHCircleIconButton(icon: .close, accessibilityLabel: "닫기") {}
        MHCircleIconButton(icon: .moreVertical, accessibilityLabel: "더보기") {}
    }
    .padding()
}
