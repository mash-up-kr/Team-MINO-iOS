import SwiftUI

// MARK: - Snackbar

/// 사용자 작업에 대한 피드백을 잠깐 띄우는 다크 바. Figma `Snackbar/Snackbar`.
///
/// 반투명 어두운 배경(`Inverse/Background` 52% + 검정 5%) 위에 흰 메시지를 얹고, 오른쪽에 후속 액션
/// 텍스트 버튼을 둔다. `title`(굵은 헤딩)·`description`(가는 설명)·`icon`(선행)·`actionTitle`(액션)·
/// `onClose`(닫기 X) 는 모두 선택이며, 준 것만 그려진다.
///
/// > 배경 블러(Figma backdrop-blur 32)는 iOS 공개 API 로 정확히 재현 불가 → 반투명 플랫 채움으로 근사한다
/// > (미디어 위 프로스트는 미구현). `MHTextArea` 등과 동일한 한계.
///
/// ```swift
/// MHSnackbar(title: "저장했어요.", actionTitle: "실행취소") { undo() }
/// MHSnackbar(title: "메시지에 마침표를 찍어요.", description: "설명은 필요할 때만 써요.")
/// MHSnackbar(title: "링크를 복사했어요.", icon: .link, onClose: { dismiss() })
/// ```
public struct MHSnackbar: View {
    private let title: String?
    private let description: String?
    private let icon: MHIcon?
    private let actionTitle: String?
    private let action: (() -> Void)?
    private let onClose: (() -> Void)?

    public init(
        title: String? = nil,
        description: String? = nil,
        icon: MHIcon? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.onClose = onClose
    }

    private let messageOpacity: Double = 0.88   // Figma Opacity/88

    public var body: some View {
        HStack(spacing: 12) {
            content
            if let actionTitle { actionButton(actionTitle) }
            if let onClose { closeButton(onClose) }
        }
        .frame(minHeight: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 420)
    }

    // 선행 아이콘 + 메시지(제목/설명).
    private var content: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(icon).resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.mhStaticWhite)
                    .opacity(messageOpacity)
            }
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title)
                        .mhTypography(.body2NormalBold)          // SUITE Bold 15
                        .foregroundStyle(.mhStaticWhite)
                        .opacity(messageOpacity)
                }
                if let description {
                    Text(description)
                        .mhTypography(.label2Regular)            // SUITE Regular 13
                        .foregroundStyle(.mhStaticWhite)
                        .opacity(messageOpacity)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 후속 액션(텍스트 버튼). Figma Button/Text — 흰 Bold 15, 눌림 시 옅은 흰 하이라이트.
    private func actionButton(_ label: String) -> some View {
        Button(action: { action?() }) {
            Text(label)
                .mhTypography(.body2NormalBold)
                .foregroundStyle(.mhStaticWhite)
                .frame(minWidth: 40)
                .padding(.vertical, 4)
        }
        .buttonStyle(SnackbarActionStyle())
        .padding(.horizontal, 2)
    }

    // 닫기(X). close 아이콘 20pt, 흰 61%. 눌림 시 옅은 흰 원 헤일로.
    private func closeButton(_ onClose: @escaping () -> Void) -> some View {
        Button(action: onClose) {
            Image(MHIcon.close).resizable().scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.mhStaticWhite)
                .opacity(0.61)                                    // Figma Opacity/61
        }
        .buttonStyle(SnackbarCloseStyle())
        .padding(2)
    }

    // 배경: Inverse/Background 52% + 검정 5%(blur 는 근사 생략).
    private var background: some View {
        ZStack {
            Color.mhInverseBackground.opacity(0.52)               // Figma Opacity/52
            Color.black.opacity(0.05)                             // Figma Primary/Normal Opacity/5
        }
    }
}

// MARK: - ButtonStyle

// 액션 텍스트버튼: 눌림 시 좌우 7pt 넓힌 흰 하이라이트(rounded 6). Figma Interaction 레이어.
private struct SnackbarActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.mhStaticWhite.opacity(0.12))
                        .padding(.horizontal, -7)
                }
            }
    }
}

// 닫기 버튼: 눌림 시 둘레 8pt 흰 원 헤일로. Figma inset-[-8px] rounded-full.
private struct SnackbarCloseStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Circle().fill(Color.mhStaticWhite.opacity(0.12)).padding(-8)
                }
            }
    }
}

#Preview("MHSnackbar") {
    VStack(spacing: 12) {
        MHSnackbar(title: "저장했어요.", actionTitle: "실행취소") {}
        MHSnackbar(title: "메시지에 마침표를 찍어요.", description: "설명은 필요할 때만 써요.", actionTitle: "텍스트") {}
        MHSnackbar(title: "링크를 복사했어요.", icon: .circleCheck, onClose: {})
    }
    .padding()
    .frame(width: 360)
    .background(Color(white: 0.9))
}
