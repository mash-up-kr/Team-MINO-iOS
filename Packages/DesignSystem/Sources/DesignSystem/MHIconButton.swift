import SwiftUI

/// 원형 아이콘 전용 버튼. Figma `Button/Icon/Outlined`(component node 2400:132990).
///
/// `Button/Button`(``MHButton``)과는 별도 컴포넌트다. `MHButton` 의 icon-only 는 size 별 radius를 갖는
/// 정사각(square)인 반면, 이 컴포넌트는 항상 40×40 **완전한 원형**이라 `MHButton` 의 per-size metric 축에
/// 끼워 넣기보다 별도 타입으로 두는 편이 정직하다. 지금은 이 화면이 쓰는 outlined 하나뿐이라
/// variant 축 없이 최소로 제공한다(figma 매트릭스가 늘면 그때 확장).
///
/// - 크기: 40×40 고정, 내부 padding 10 → 아이콘 20×20.
/// - 배경: 투명. 테두리: `Line/Normal/Neutral` 1px. 아이콘 색: `Label/Normal`.
/// - press: `Label/Normal` 오버레이(``MHButton`` 과 동일 opacity 계열). `.disabled` 로 비활성 처리.
/// - icon-only 라 VoiceOver 라벨이 없다 — `accessibilityLabel` 로 전달하면 부여된다(권장).
///
/// ```swift
/// MHIconButton(icon: .plus, accessibilityLabel: "방 추가") { addRoom() }
/// ```
public struct MHIconButton: View {
    private let icon: MHIcon
    private let accessibilityLabel: String?
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(icon: MHIcon, accessibilityLabel: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: MHIconButtonMetric.iconSize, height: MHIconButtonMetric.iconSize)
        }
        .buttonStyle(MHIconButtonStyle(isEnabled: isEnabled))
        .modifier(OptionalAccessibilityLabel(label: accessibilityLabel))
    }
}

/// `accessibilityLabel` 이 `nil` 이면 시스템 기본(라벨 없음)을 그대로 둔다 — 빈 문자열로 덮어써 접근성을 해치지 않기 위함.
private struct OptionalAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

// MARK: - Metric (Figma 실측)

enum MHIconButtonMetric {
    static let size: CGFloat = 40
    static let iconSize: CGFloat = 20
}

// MARK: - ButtonStyle (배경·테두리·press 오버레이)

private struct MHIconButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let fg: Color = isEnabled ? .mhLabelNormal : .mhLabelDisable
        configuration.label
            .foregroundStyle(fg)
            .frame(width: MHIconButtonMetric.size, height: MHIconButtonMetric.size)
            .overlay {
                // press 인터랙션 오버레이. MHButtonStyle 의 outlined 계열과 동일 규칙(Label/Normal, 0.18).
                if configuration.isPressed {
                    Color.mhLabelNormal.opacity(MHButtonStyle.pressedOpacity)
                }
            }
            .overlay {
                Circle().strokeBorder(.mhLineNormalNeutral, lineWidth: 1)
            }
            .clipShape(Circle())
    }
}

#Preview("MHIconButton") {
    HStack(spacing: 12) {
        MHIconButton(icon: .plus) {}
        MHIconButton(icon: .plus) {}.disabled(true)
    }
    .padding()
}
