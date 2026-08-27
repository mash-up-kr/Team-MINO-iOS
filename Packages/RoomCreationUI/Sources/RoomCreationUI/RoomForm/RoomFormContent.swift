import DesignSystem
import Domain
import SwiftUI

// MARK: - 모드별 문구

private extension RoomFormMode {
    var title: String {
        switch self {
        case .create: "공동방 만들기"
        case .edit:   "방 편집"
        }
    }

    var submitTitle: String {
        switch self {
        case .create: "방 생성하기"
        case .edit:   "방 편집 완료"
        }
    }

    var cancelDialogTitle: String {
        switch self {
        case .create: "공동방 만들기 화면에서 나가시겠어요?"
        case .edit:   "공동방 편집 화면에서 나가시겠어요?"
        }
    }
}

// MARK: - RoomFormContent

/// 공동방 만들기/편집 화면의 순수 마크업. **Store·Coordinator 를 모른다** — 상태 값과 액션 싱크만 받는다.
///
/// `RoomFormState`·`RoomFormAction` 은 같은 모듈의 순수 value type 이라 이 둘을 받아도 원칙이 깨지지
/// 않는다. 값 8개와 래퍼 클로저 5개를 따로 받던 것을 묶은 것으로, 액션이나 검증 프로퍼티가 늘 때마다
/// Content·View·Preview 세 곳을 함께 고치던 일이 사라진다.
struct RoomFormContent: View {
    let state: RoomFormState
    let send: (RoomFormAction) -> Void
    /// 상단바 건너뛰기 노출. 건너뛸 수 없는 진입점(방리스트·편집 등)은 `false`.
    let showsSkip: Bool
    /// 상단바 뒤로가기 노출. 온보딩은 돌아갈 곳이 없어 `false`(디자인 ⑦).
    let showsBack: Bool

    /// Figma `2314:95303` 실측 — 카드 padding 14 + 썸네일 80 → 카드 높이 108.
    private enum Metric {
        static let thumbnailSize: CGFloat = 80
    }

    private let namePlaceholder = "방 이름을 입력해 주세요."
    private let descriptionPlaceholder = "어떤 장소들을 모으는 방인가요?"

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(
                title: state.mode.title,
                onBack: showsBack ? { send(.tapBack) } : nil,
                onSkip: showsSkip ? { send(.tapSkip) } : nil
            )
            ScrollView {
                VStack(spacing: 30) {
                    previewCard
                    nameField
                    descriptionField
                    colorPicker
                }
                .padding(20)
            }
            // 액션 영역을 VStack 자식으로 두면 키보드가 올라올 때 MHActionArea 의 하단 안전영역 측정에
            // 키보드 높이가 섞여 스크롤뷰가 찌그러진다. safeAreaInset 으로 붙여 키보드 회피를 맡긴다.
            .safeAreaInset(edge: .bottom) {
                MHActionArea(
                    main: MHAction(state.mode.submitTitle) { send(.tapSubmit) },
                    sticky: true,
                    safeArea: false
                )
                .disabled(!state.isSubmitEnabled)
            }
        }
        .background(Color.mhBackgroundNormalNormal)
        // 방 설명(MHTextArea)은 리턴키가 개행이라 리턴키로 못 닫는다. 키보드가 하단을 가리면 방 색상
        // 그리드에 접근 자체가 안 되므로(이슈 #93) 스크롤·여백 탭 두 탈출로를 함께 건다.
        .mhFormKeyboardDismissal()
        .mhDialog(item: state.dialog) { confirmDialog($0) }
        .overlay(alignment: .bottom) { saveErrorSnackbar }
    }

    // MARK: 저장 실패 안내
    //
    // 저장 실패는 화면을 넘기지 않고 여기서만 알린다 — 입력이 그대로 남아 다시 누르면 재시도가 된다.

    @ViewBuilder private var saveErrorSnackbar: some View {
        if let saveError = state.saveError {
            MHSnackbar(title: saveError.roomSaveMessage)
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .transition(.opacity)
                .accessibilityIdentifier("RoomForm.saveError")
        }
    }

    // MARK: 확인 다이얼로그
    //
    // Figma `3798:167740`(저장) · `3798:167985`(만들기 나가기) · `3832:213756`(편집 나가기).
    // 셋 다 타이틀 한 줄 + 버튼 두 개다 — 설명 문구는 없다.

    private func confirmDialog(_ dialog: RoomFormDialog) -> MHDialog {
        switch dialog {
        case .saveConfirm:
            MHDialog(
                title: "공동방을 저장하시겠어요?",
                cancel: MHAction("취소") { send(.dismissDialog) },
                confirm: MHAction("저장하기") { send(.confirmSubmit) }
            )
        case .cancelConfirm:
            MHDialog(
                title: state.mode.cancelDialogTitle,
                cancel: MHAction("취소") { send(.dismissDialog) },
                confirm: MHAction("나가기") { send(.confirmCancel) }
            )
        }
    }

    // MARK: 미리보기 카드

    private var previewCard: some View {
        HStack(spacing: 12) {
            roomThumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(state.roomName.isEmpty ? namePlaceholder : state.roomName)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(Color.mhLabelNormal)
                Text(state.roomDescription.isEmpty ? descriptionPlaceholder : state.roomDescription)
                    .mhTypography(.caption2Medium)
                    .foregroundStyle(Color.mhLabelAlternative)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mhBackgroundElevatedNormal, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(Color.mhLineSolidNormal, lineWidth: 1)
        }
        // 카드는 한 덩어리로 읽는다 — combine 이 없으면 식별자가 자식(썸네일·이름·설명)마다 복제돼
        // QA 자동화의 선택자가 다중 매치된다.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("RoomForm.previewCard")
    }

    // 고른 색의 방 썸네일. 아직 안 골랐으면 my-room 일러스트(Figma `Room Thumbnail_Empty` 기본 상태).
    @ViewBuilder private var roomThumbnail: some View {
        if let index = state.selectedColorIndex, let color = RoomColorPalette.thumbnail(at: index) {
            MHRoomThumbnail(color: color, size: Metric.thumbnailSize)
        } else {
            MHRoomThumbnail.myRoom(size: Metric.thumbnailSize)
        }
    }

    // MARK: 입력 필드

    private var nameField: some View {
        MHTextField(
            namePlaceholder,
            text: binding(\.roomName, RoomFormAction.roomNameChanged),
            heading: "방 이름",
            isRequired: true,
            // 오류 문구를 따로 두지 않는다 — 디자인(001-1-3)은 같은 안내문을 빨갛게 물들인다.
            description: "한글·영문·숫자만 입력 가능해요. (공백 포함 \(RoomFormLimit.name)자 이내)",
            status: state.isNameValid ? .normal : .negative,
            identifier: "RoomForm.nameField"
        )
    }

    private var descriptionField: some View {
        MHTextArea(
            descriptionPlaceholder,
            text: binding(\.roomDescription, RoomFormAction.roomDescriptionChanged),
            heading: "방 설명",
            status: state.isDescriptionValid ? .normal : .negative,
            identifier: "RoomForm.descriptionField",
            bottomLeading: {
                MHCharacterCounter(count: state.roomDescription.count, limit: RoomFormLimit.description)
            }
        )
    }

    // MARK: 색상 선택

    private var colorPicker: some View {
        MHSelectionGrid(
            title: "방 색상 선택",
            items: RoomColorPalette.gridItems,
            selectedIndex: state.selectedColorIndex,
            shape: .roundedSquare,
            identifierPrefix: "RoomForm.color",
            onSelect: { send(.selectColor($0)) }
        )
    }

    /// 읽기는 state, 쓰기는 액션으로 — `@Binding` 두 개를 따로 받지 않아도 된다.
    private func binding(
        _ keyPath: KeyPath<RoomFormState, String>,
        _ action: @escaping (String) -> RoomFormAction
    ) -> Binding<String> {
        Binding(get: { state[keyPath: keyPath] }, set: { send(action($0)) })
    }

}

// MARK: - Preview

#Preview("버튼 활성") {
    PreviewHost(roomName: "민호야 잘하자", roomDescription: "팀 회식 장소 모음", selectedColorIndex: 2)
}

#Preview("버튼 비활성") {
    PreviewHost(roomName: "", roomDescription: "", selectedColorIndex: 0)
}

#Preview("입력 오류") {
    PreviewHost(roomName: "민호야 잘하자^^", roomDescription: String(repeating: "가", count: 31), selectedColorIndex: 5)
}

#Preview("저장 확인 다이얼로그") {
    PreviewHost(roomName: "민호야 잘하자", roomDescription: "팀 회식 장소 모음", selectedColorIndex: 2, dialog: .saveConfirm)
}

#Preview("취소 확인 다이얼로그") {
    PreviewHost(roomName: "", roomDescription: "", selectedColorIndex: nil, dialog: .cancelConfirm)
}

#Preview("편집 취소 확인 다이얼로그") {
    PreviewHost(
        mode: .edit,
        roomName: "야호",
        roomDescription: "야호호",
        selectedColorIndex: 0,
        dialog: .cancelConfirm,
        showsSkip: false
    )
}

#Preview("건너뛰기 없음") {
    PreviewHost(roomName: "민호야 잘하자", roomDescription: "팀 회식 장소 모음", selectedColorIndex: 2, showsSkip: false)
}

#Preview("온보딩 — 뒤로가기 없음") {
    PreviewHost(roomName: "", roomDescription: "", selectedColorIndex: nil, showsBack: false)
}

#Preview("저장 실패") {
    PreviewHost(
        roomName: "민호야 잘하자",
        roomDescription: "팀 회식 장소 모음",
        selectedColorIndex: 2,
        saveError: .roomSaveFailed
    )
}

#Preview("편집 모드") {
    PreviewHost(
        mode: .edit,
        roomName: "야호",
        roomDescription: "야호호",
        selectedColorIndex: 0,
        showsSkip: false
    )
}

/// 실제 `roomFormReducer` 를 태운다 — 손으로 전이를 흉내 내면 프리뷰가 reducer 규칙과 갈라진다.
private struct PreviewHost: View {
    @State private var state: RoomFormState
    private let showsSkip: Bool
    private let showsBack: Bool
    private let reduce = roomFormReducer(.create(create: PreviewCreateRoomUseCase()))

    init(
        mode: RoomFormMode = .create,
        roomName: String,
        roomDescription: String,
        selectedColorIndex: Int?,
        dialog: RoomFormDialog? = nil,
        saveError: DomainError? = nil,
        showsSkip: Bool = true,
        showsBack: Bool = true
    ) {
        var state = RoomFormState(
            mode: mode,
            roomName: roomName,
            roomDescription: roomDescription,
            selectedColorIndex: selectedColorIndex
        )
        state.dialog = dialog
        state.saveError = saveError
        self._state = State(initialValue: state)
        self.showsSkip = showsSkip
        self.showsBack = showsBack
    }

    var body: some View {
        RoomFormContent(
            state: state,
            // 프리뷰에는 Store 가 없으므로 Effect(전환·비동기)는 버린다 — state 전이만 본다.
            send: { _ = reduce(&state, $0) },
            showsSkip: showsSkip,
            showsBack: showsBack
        )
    }
}

/// 프리뷰는 `Effect` 를 버리므로 이 UseCase 는 호출되지 않는다 — reducer 시그니처만 채운다.
private struct PreviewCreateRoomUseCase: CreateRoomUseCase {
    func execute(name: String, description: String?, color: RoomColor) async throws -> Room {
        throw CancellationError()
    }
}
