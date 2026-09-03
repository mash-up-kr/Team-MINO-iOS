import SwiftUI

/// 강조 위계. `primary`(Primary/Normal) / `assistive`(Label/Alternative). Figma `Button/Text` variant.
public enum MHTextButtonVariant: Sendable { case primary, assistive }

/// 배경·테두리 없이 텍스트만으로 동작하는 낮은 위계의 버튼. Figma `Button/Text`.
///
/// 부가적이지만 강조가 필요한 액션(예: TextArea 하단 "전송"·"지우기")에 쓴다.
/// `primary`(검정 강조) / `assistive`(보조 회색). 글자는 ``MHTypography``(SUITE) — 입력이 아니라 라벨.
///
/// ```swift
/// MHTextButton("전송") { send() }                       // primary
/// MHTextButton("지우기", variant: .assistive) { clear() }
/// MHTextButton("확인") { ok() }.disabled(true)          // 표준 .disabled
/// ```
public struct MHTextButton: View {
    private let title: String
    private let variant: MHTextButtonVariant
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, variant: MHTextButtonVariant = .primary, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).mhTypography(.body1NormalBold)
        }
        .buttonStyle(MHTextButtonStyle(variant: variant, isEnabled: isEnabled))
    }
}

// MARK: - 색 (Figma 실측)

extension MHTextButtonVariant {
    // 라벨 색: primary=Primary/Normal(검정), assistive=Label/Alternative. 비활성=Label/Disable.
    func foreground(isEnabled: Bool) -> Color {
        guard isEnabled else { return .mhLabelDisable }
        return self == .primary ? .mhPrimaryNormal : .mhLabelAlternative
    }
    // pressed 오버레이 색: primary=Primary/Normal, assistive=Label/Normal.
    var pressedOverlay: Color { self == .primary ? .mhPrimaryNormal : .mhLabelNormal }
}

// MARK: - ButtonStyle (py-4 + pressed 오버레이)

struct MHTextButtonStyle: ButtonStyle {
    let variant: MHTextButtonVariant
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(variant.foreground(isEnabled: isEnabled))
            .padding(.vertical, 4)                    // Figma py-4
            .frame(minWidth: 42)                      // Figma Button/Text w-[42px](짧은 라벨은 42, 길면 hug)
            .background {
                // Figma Interaction: rounded-6, 좌우 -7 확장(여기선 padding 으로 근사). pressed 시만 표시.
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(variant.pressedOverlay.opacity(0.09))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview("MHTextButton") {
    HStack(spacing: 16) {
        MHTextButton("Primary") {}
        MHTextButton("Assistive", variant: .assistive) {}
        MHTextButton("Disabled") {}.disabled(true)
    }
    .padding()
}
