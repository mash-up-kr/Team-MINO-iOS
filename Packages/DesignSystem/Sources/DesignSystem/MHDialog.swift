import SwiftUI

/// 진행 여부를 되묻는 확인 다이얼로그. Figma `001-1-4 공동방_저장/취소 여부 묻기`(node 3798:167740).
///
/// 딤 위에 뜨는 흰 카드 — 타이틀(+선택 설명)과 **취소/확인 두 버튼**이 항상 한 쌍이다.
/// 단일 액션이나 3개 이상은 이 컴포넌트가 아니라 시트·메뉴로 표현한다.
///
/// 화면에 직접 얹지 말고 ``SwiftUICore/View/mhDialog(item:content:)`` 로 띄운다 — 딤·중앙 정렬·
/// 바깥 터치 차단이 거기 들어 있고, **어디에 붙이든 화면 전체**를 덮는다.
///
/// ```swift
/// .mhDialog(item: store.state.dialog) { _ in
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
    ///
    /// > `Binding` 이 아니라 값을 받는다. 닫는 책임이 전부 호출처(reducer)에 있어 이 modifier 는
    /// > 되쓸 일이 없다 — `Binding` 을 받으면 "닫기는 알아서 한다"는 없는 계약을 암시하게 된다.
    func mhDialog<Item: Identifiable>(
        item: Item?,
        @ViewBuilder content: @escaping (Item) -> MHDialog
    ) -> some View {
        modifier(MHDialogPresentation(item: item, dialog: content))
    }
}

/// 다이얼로그를 **창 단위로** 띄운다.
///
/// > `overlay` 로 그리면 붙인 뷰의 프레임을 못 벗어난다 — `ignoresSafeArea` 는 safe area 로만 넓히지
/// > 부모 경계를 뚫지 못하고, ``MHBottomSheet`` 는 콘텐츠를 `clipShape` 로 자른다. 그래서 시트 안에서
/// > 쓰면 딤이 시트에만 걸리고 다이얼로그도 시트 한가운데 뜬다(방 상세 장소 삭제·장소 상세 코멘트
/// > 삭제에서 실제로 발생). 붙이는 자리에 따라 맞고 틀리는 구조라 같은 실수가 두 번 났다 —
/// > 호출처가 z-order 를 신경 쓰지 않도록 표시 자체를 화면 밖으로 올린다.
///
/// 커버 기본 전환(아래에서 밀어올림)은 다이얼로그에 맞지 않아 끄고, 안쪽 `opacity` 로 페이드한다.
private struct MHDialogPresentation<Item: Identifiable>: ViewModifier {
    let item: Item?
    let dialog: (Item) -> MHDialog

    @State private var isPresented = false
    @State private var isVisible = false
    /// 페이드아웃 동안 그릴 마지막 값. `item` 이 nil 이 되는 즉시 놓으면 사라지는 모습이 안 보인다.
    @State private var lingering: Item?

    private var fade: Animation { .easeInOut(duration: 0.2) }

    func body(content: Content) -> some View {
        content
            .onChange(of: item?.id, initial: true) { _, id in sync(hasItem: id != nil) }
            .fullScreenCover(isPresented: $isPresented) {
                ZStack {
                    Color.mhMaterialDimmer
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {}
                    // 살아 있는 `item` 을 먼저 본다 — id 가 같은 채 내용만 바뀌는 변화(제출 중 버튼
                    // 비활성 등)가 붙잡아 둔 값에 막히지 않아야 한다.
                    if let value = item ?? lingering { dialog(value) }
                }
                .opacity(isVisible ? 1 : 0)
                .presentationBackground(.clear)
                .task { withAnimation(fade) { isVisible = true } }
            }
    }

    private func sync(hasItem: Bool) {
        if hasItem {
            lingering = item
            if isPresented {
                // 페이드아웃 중에 다시 떴다 — 커버는 그대로 두고 되돌린다.
                withAnimation(fade) { isVisible = true }
            } else {
                // 페이드인은 커버의 `.task` 몫이다. 여기서 켜면 커버가 이미 불투명한 채로 나타난다.
                withoutPresentationAnimation { isPresented = true }
            }
        } else if isPresented {
            withAnimation(fade) { isVisible = false } completion: {
                // 그 사이 다시 떴으면(`isVisible` 이 되살아났으면) 커버를 유지한다.
                guard !isVisible else { return }
                withoutPresentationAnimation { isPresented = false }
                lingering = nil
            }
        }
    }

    private func withoutPresentationAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}

// MARK: - Preview

#Preview("저장 여부 묻기") {
    Color.mhBackgroundNormalAlternative
        .ignoresSafeArea()
        .mhDialog(item: PreviewDialog.save) { _ in
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
        .mhDialog(item: PreviewDialog.save) { _ in
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
