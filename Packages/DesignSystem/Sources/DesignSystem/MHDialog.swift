import SwiftUI

/// 진행 여부를 되묻는 확인 다이얼로그. Figma `001-1-4 공동방_저장/취소 여부 묻기`(node 3798:167740).
///
/// 딤 위에 뜨는 흰 카드 — 타이틀(+선택 설명)과 **취소/확인 두 버튼**이 항상 한 쌍이다.
/// 단일 액션이나 3개 이상은 이 컴포넌트가 아니라 시트·메뉴로 표현한다.
///
/// 화면에 직접 얹지 말고 ``SwiftUICore/View/mhDialog(item:content:)`` 로 띄운다 — 딤·중앙 정렬·
/// 바깥 터치 차단이 거기 들어 있다.
///
/// ```swift
/// .mhDialog(item: $dialog) { _ in
///     MHDialog(
///         title: "공동방을 저장하시겠어요?",
///         message: "공동방 편집에서 설정을 변경할 수 있어요.",
///         cancel: MHAction("취소") { store.send(.dismissDialog) },
///         confirm: MHAction("저장하기") { store.send(.confirmSubmit) }
///     )
/// }
/// ```
///
/// > 버튼 스타일은 다이얼로그 고정이라 ``MHAction`` 의 `variant`·`color` 는 읽지 않는다
/// > (`title`·`isEnabled`·`action` 만 쓴다). 크기·radius 가 ``MHButton`` 프리셋과 달라 직접 그린다.
public struct MHDialog: View {
    private let title: String
    private let message: String?
    private let cancel: MHAction
    private let confirm: MHAction

    public init(title: String, message: String? = nil, cancel: MHAction, confirm: MHAction) {
        self.title = title
        self.message = message
        self.cancel = cancel
        self.confirm = confirm
    }

    public var body: some View {
        VStack(spacing: Metric.sectionGap) {
            VStack(spacing: Metric.textGap) {
                Text(title)
                    .mhTypography(.body1ReadingBold)
                    .foregroundStyle(Color.mhLabelNormal)
                    .accessibilityIdentifier("MHDialog.title")
                if let message {
                    Text(message)
                        .mhTypography(.label2Regular)
                        .foregroundStyle(Color.mhLabelNeutral)
                        .accessibilityIdentifier("MHDialog.message")
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            HStack(spacing: Metric.buttonGap) {
                button(cancel, isConfirm: false)
                button(confirm, isConfirm: true)
            }
        }
        .padding(.top, Metric.topPadding)
        .padding(.horizontal, Metric.hPadding)
        .padding(.bottom, Metric.bottomPadding)
        .frame(width: Metric.cardWidth)
        .background(Color.mhBackgroundNormalNormal, in: RoundedRectangle(cornerRadius: Metric.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.cornerRadius)
                .strokeBorder(Color.mhLineNormalAlternative, lineWidth: 1)
        }
        .accessibilityIdentifier("MHDialog")
    }

    // 취소=Background/Normal/Alternative + Label/Normal, 확인=Primary/Normal + Inverse/Label.
    //
    // Figma 는 라벨을 `Static/White`·`Static/Black` 으로 찍어 뒀지만 그건 라이트 모드만 그린 시안이다.
    // 그대로 쓰면 다크에서 Primary/Normal 이 흰색으로 뒤집히면서 **흰 배경에 흰 글씨**가 된다
    // (시뮬레이터 확인). 배경을 따라 뒤집히는 시맨틱 토큰으로 매핑한다 — 라이트 실측값은 동일하고,
    // `MHButton` 의 solid/primary 가 `.mhInverseLabel` 을 쓰는 것과 같은 규칙이다.
    @ViewBuilder private func button(_ action: MHAction, isConfirm: Bool) -> some View {
        Button(action: action.action) {
            Text(action.title)
                .mhTypography(.body1NormalMedium)
                .foregroundStyle(action.isEnabled
                    ? (isConfirm ? Color.mhInverseLabel : Color.mhLabelNormal)
                    : Color.mhLabelAssistive)
                .frame(maxWidth: .infinity)
                .frame(height: Metric.buttonHeight)
                .background(
                    action.isEnabled
                        ? (isConfirm ? Color.mhPrimaryNormal : Color.mhBackgroundNormalAlternative)
                        : Color.mhInteractionDisable,
                    in: RoundedRectangle(cornerRadius: Metric.buttonRadius)
                )
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .accessibilityIdentifier(isConfirm ? "MHDialog.confirmButton" : "MHDialog.cancelButton")
    }

    private enum Metric {
        static let cardWidth: CGFloat = 300
        static let cornerRadius: CGFloat = 24
        static let topPadding: CGFloat = 24
        static let hPadding: CGFloat = 24
        static let bottomPadding: CGFloat = 20
        static let sectionGap: CGFloat = 28
        static let textGap: CGFloat = 4
        static let buttonGap: CGFloat = 12
        static let buttonHeight: CGFloat = 44
        static let buttonRadius: CGFloat = 8
    }
}

// MARK: - 표시 modifier

public extension View {
    /// `item` 이 non-nil 인 동안 딤 위에 ``MHDialog`` 를 띄운다.
    ///
    /// 딤은 탭을 **먹기만 하고 닫지 않는다** — 두 선택지 중 하나를 반드시 고르게 하는 게 이 다이얼로그의
    /// 목적이라, 바깥 탭으로 빠져나가면 "취소" 와 구분이 안 된다.
    func mhDialog<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> MHDialog
    ) -> some View {
        overlay {
            if let value = item.wrappedValue {
                ZStack {
                    Color.mhMaterialDimmer
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {}
                    content(value)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: item.wrappedValue != nil)
    }
}

// MARK: - Preview

#Preview("저장 여부 묻기") {
    Color.mhBackgroundNormalAlternative
        .ignoresSafeArea()
        .mhDialog(item: .constant(PreviewDialog.save)) { _ in
            MHDialog(
                title: "공동방을 저장하시겠어요?",
                message: "공동방 편집에서 설정을 변경할 수 있어요.",
                cancel: MHAction("취소") {},
                confirm: MHAction("저장하기") {}
            )
        }
}

#Preview("설명 없음") {
    Color.mhBackgroundNormalAlternative
        .ignoresSafeArea()
        .mhDialog(item: .constant(PreviewDialog.save)) { _ in
            MHDialog(
                title: "정말 나가시겠어요?",
                cancel: MHAction("취소") {},
                confirm: MHAction("나가기") {}
            )
        }
}

private enum PreviewDialog: Identifiable {
    case save
    var id: Self { self }
}
