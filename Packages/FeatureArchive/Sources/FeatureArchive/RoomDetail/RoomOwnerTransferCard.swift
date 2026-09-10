import DesignSystem
import ProfileSetupUI
import SwiftUI

/// 방장이 방을 나가려 할 때 새 방장을 고르는 카드(004-5 뒤).
///
/// **확정 시안이 없다.** Figma 3개 페이지를 이름·텍스트 레이어·좌표 인접성으로 전수 확인했지만
/// 「방장 위임 대상 선택 모달」에 해당하는 프레임이 없다(API 스펙의 `GET /rooms/{id}/members` 설명이
/// 그 모달을 전제하고 있는데도 그렇다). 그래서 이 앱 확인 모달의 공통 꼴(``MHDialog``)을 그대로
/// 따르고 — 같은 폭·radius·버튼 — 가운데에 참여자 목록만 끼워 넣었다. 참여자 행은 친구 초대
/// 시트(`RoomInviteSheetContent.row`)와 같은 구성이다(``MHAvatar`` + 닉네임).
///
/// 시안이 오면 이 파일만 갈면 된다 — 상태(``RoomOwnerTransfer``)와 흐름은 그대로 쓸 수 있다.
struct RoomOwnerTransferCard: View {
    let transfer: RoomOwnerTransfer
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    /// 목록이 길어도 카드가 화면을 넘지 않게 — 4행쯤에서 스크롤로 넘긴다.
    private static let listMaxHeight: CGFloat = 232

    var body: some View {
        VStack(spacing: Metric.sectionGap) {
            header
            list
            buttons
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
        .accessibilityIdentifier("RoomOwnerTransfer")
    }

    private var header: some View {
        VStack(spacing: Metric.textGap) {
            Text("새 방장을 정해주세요")
                .mhTypography(.body1ReadingBold)
                .foregroundStyle(Color.mhLabelNormal)
                .accessibilityIdentifier("RoomOwnerTransfer.title")
            Text(message)
                .mhTypography(.label2Regular)
                .foregroundStyle(transfer.failed ? Color.mhStatusNegative : Color.mhLabelNeutral)
                .accessibilityIdentifier("RoomOwnerTransfer.message")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var message: String {
        transfer.failed
            ? "방장을 넘기지 못했어요. 잠시 후 다시 시도해 주세요."
            : "방장은 혼자 나갈 수 없어요. 방장을 넘길 참여자를 골라주세요."
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(transfer.candidates) { candidate in
                    row(candidate)
                }
            }
        }
        .frame(maxHeight: Self.listMaxHeight)
        // 후보가 적으면 목록이 그만큼만 차지한다 — 빈 스크롤 영역을 남기지 않는다.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("RoomOwnerTransfer.list")
    }

    private func row(_ candidate: RoomOwnerTransferCandidate) -> some View {
        let isSelected = transfer.selectedID == candidate.id
        return Button {
            onSelect(candidate.id)
        } label: {
            HStack(spacing: 12) {
                MHAvatar(AvatarPalette.image(of: candidate.avatarColor), size: 36)
                Text(candidate.nickname)
                    .mhTypography(.label1NormalMedium)
                    .foregroundStyle(Color.mhLabelNormal)
                    .lineLimit(1)
                Spacer(minLength: 8)
                // 고른 사람에만 체크를 붙인다. 라디오 컴포넌트가 DS 에 없어(``MHCheckbox`` 는
                // 다중 선택용 사각 체크박스다) 선택 표시는 아이콘 하나로 둔다.
                if isSelected {
                    Image(.checkThick)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.mhPrimaryNormal)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(transfer.isSubmitting)
        .accessibilityIdentifier("RoomOwnerTransfer.candidate.\(candidate.id)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var buttons: some View {
        HStack(spacing: Metric.buttonGap) {
            button("취소", isConfirm: false, isEnabled: !transfer.isSubmitting, action: onCancel)
            button("넘기고 나가기", isConfirm: true, isEnabled: transfer.canSubmit, action: onConfirm)
        }
    }

    /// ``MHDialog`` 의 버튼과 같은 규칙(색·높이·radius). DS 가 그 스타일을 열어 두지 않아
    /// 여기서 같은 값으로 그린다 — 다이얼로그 버튼이 컴포넌트로 빠지면 그때 바꿔 쓴다.
    @ViewBuilder
    private func button(
        _ title: String,
        isConfirm: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .mhTypography(.body1NormalMedium)
                .foregroundStyle(isEnabled
                    ? (isConfirm ? Color.mhInverseLabel : Color.mhLabelNormal)
                    : Color.mhLabelAssistive)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: Metric.buttonHeight)
                .background(
                    isEnabled
                        ? (isConfirm ? Color.mhPrimaryNormal : Color.mhBackgroundNormalAlternative)
                        : Color.mhInteractionDisable,
                    in: RoundedRectangle(cornerRadius: Metric.buttonRadius)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(
            isConfirm ? "RoomOwnerTransfer.confirmButton" : "RoomOwnerTransfer.cancelButton"
        )
    }

    // ``MHDialog/Metric`` 과 같은 값. 두 카드가 나란히 뜨지는 않지만 연달아 뜨므로 폭·radius 가
    // 어긋나면 그 전환이 눈에 띈다.
    private enum Metric {
        static let cardWidth: CGFloat = 300
        static let cornerRadius: CGFloat = 24
        static let topPadding: CGFloat = 24
        static let hPadding: CGFloat = 24
        static let bottomPadding: CGFloat = 20
        static let sectionGap: CGFloat = 20
        static let textGap: CGFloat = 4
        static let buttonGap: CGFloat = 12
        static let buttonHeight: CGFloat = 44
        static let buttonRadius: CGFloat = 8
    }
}

extension View {
    /// 시트를 담은 껍데기에 붙인다 — 시트 클립 밖에서 그려야 딤이 화면 전체를 덮는다
    /// (``roomDetailMoreMenu(store:detent:)`` 와 같은 이유).
    ///
    /// 딤은 탭을 먹기만 하고 닫지 않는다 — ``SwiftUICore/View/mhDialog(item:content:)`` 와 같은 규칙.
    @ViewBuilder
    func roomOwnerTransfer(store: RoomDetailStore?) -> some View {
        overlay {
            if let store, let transfer = store.state.ownerTransfer {
                ZStack {
                    Color.mhMaterialDimmer
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {}
                    RoomOwnerTransferCard(
                        transfer: transfer,
                        onSelect: { store.send(.selectNextOwner($0)) },
                        onCancel: { store.send(.cancelOwnerTransfer) },
                        onConfirm: { store.send(.confirmOwnerTransfer) }
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.ownerTransfer)
    }
}

#Preview("새 방장 고르기") {
    Color.mhBackgroundNormalAlternative
        .ignoresSafeArea()
        .overlay {
            RoomOwnerTransferCard(
                transfer: RoomOwnerTransfer(
                    candidates: [
                        RoomOwnerTransferCandidate(id: "u1", nickname: "민호", avatarColor: .red),
                        RoomOwnerTransferCandidate(id: "u2", nickname: "유빈", avatarColor: .cyan),
                        RoomOwnerTransferCandidate(id: "u3", nickname: "윤지", avatarColor: nil),
                    ],
                    selectedID: "u2"
                ),
                onSelect: { _ in },
                onCancel: {},
                onConfirm: {}
            )
        }
}
