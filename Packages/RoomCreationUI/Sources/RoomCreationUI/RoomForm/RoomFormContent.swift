import SwiftUI
import DesignSystem

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

/// "공동방 만들기" 화면의 순수 마크업. Store·Coordinator 를 모른다 — 값과 클로저만 받는다.
///
/// 카드 안 지도 썸네일은 실제 지도 에셋이 아직 없어 선택된 색으로 틴트되는 placeholder 로 그린다
/// (색을 고르면 지도 색이 바뀌는 확정 동작을 반영하기 위함). 지도 에셋이 붙으면 교체 대상이다.
struct RoomFormContent: View {
    let mode: RoomFormMode
    @Binding var roomName: String
    @Binding var roomDescription: String
    let selectedColorIndex: Int?
    let isNameValid: Bool
    let isDescriptionValid: Bool
    let isSubmitEnabled: Bool
    let dialog: RoomFormDialog?
    let onSelectColor: (Int) -> Void
    let onSubmit: () -> Void
    let onDismissDialog: () -> Void
    let onConfirmSubmit: () -> Void
    let onConfirmCancel: () -> Void
    /// `nil` 이면 상단바에 뒤로가기를 그리지 않는다 — 온보딩엔 돌아갈 곳이 없다(디자인 ⑦).
    let onBack: (() -> Void)?
    /// `nil` 이면 상단바에 건너뛰기 버튼을 그리지 않는다 — 건너뛸 수 없는 진입점(방리스트·편집 등)을 위해.
    let onSkip: (() -> Void)?

    /// Figma `2314:95303` 실측 — 카드 padding 14 + 썸네일 80 → 카드 높이 108.
    private enum Metric {
        static let thumbnailSize: CGFloat = 80
    }

    private let namePlaceholder = "방 이름을 입력해 주세요."
    private let descriptionPlaceholder = "어떤 장소들을 모으는 방인가요?"

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: mode.title, onBack: onBack, onSkip: onSkip)
            ScrollView {
                VStack(spacing: 30) {
                    previewCard
                    nameField
                    descriptionField
                    colorPicker
                }
                .padding(20)
            }
            // .interactively 가 아니라 .immediately 다. interactively 는 드래그가 키보드 영역을
            // 지나갈 때만 내려가서, 키보드 위쪽 콘텐츠를 스크롤하면 아무 일도 일어나지 않는다 —
            // 정작 가려서 못 누르는 게 아래쪽 색상 그리드라 그게 이 화면의 목적을 못 채운다(이슈 #93).
            .scrollDismissesKeyboard(.immediately)
            // 액션 영역을 VStack 자식으로 두면 키보드가 올라올 때 MHActionArea 의 하단 안전영역 측정에
            // 키보드 높이가 섞여 스크롤뷰가 찌그러진다. safeAreaInset 으로 붙여 키보드 회피를 맡긴다.
            .safeAreaInset(edge: .bottom) {
                MHActionArea(main: MHAction(mode.submitTitle, action: onSubmit), sticky: true, safeArea: false)
                    .disabled(!isSubmitEnabled)
            }
        }
        .background(Color.mhBackgroundNormalNormal)
        // 방 설명(MHTextArea)은 리턴키가 개행이라 리턴키로 못 닫는다. 스크롤 해제·툴바 '완료' 와 함께
        // 여백 탭도 열어 둔다 — 키보드가 하단을 가리면 방 색상 그리드에 접근 자체가 안 된다(이슈 #93).
        .mhDismissKeyboardOnTap()
        .mhDialog(item: .constant(dialog)) { confirmDialog($0) }
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
                cancel: MHAction("취소", action: onDismissDialog),
                confirm: MHAction("저장하기", action: onConfirmSubmit)
            )
        case .cancelConfirm:
            MHDialog(
                title: mode.cancelDialogTitle,
                cancel: MHAction("취소", action: onDismissDialog),
                confirm: MHAction("나가기", action: onConfirmCancel)
            )
        }
    }

    // MARK: 미리보기 카드

    private var previewCard: some View {
        HStack(spacing: 12) {
            roomThumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(roomName.isEmpty ? namePlaceholder : roomName)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(Color.mhLabelNormal)
                Text(roomDescription.isEmpty ? descriptionPlaceholder : roomDescription)
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
        if let selectedColorIndex, let color = RoomColorPalette.thumbnail(at: selectedColorIndex) {
            MHRoomThumbnail(color: color, size: Metric.thumbnailSize)
        } else {
            MHRoomThumbnail.myRoom(size: Metric.thumbnailSize)
        }
    }

    // MARK: 입력 필드

    private var nameField: some View {
        MHTextField(
            namePlaceholder,
            text: $roomName,
            heading: "방 이름",
            isRequired: true,
            // 오류 문구를 따로 두지 않는다 — 디자인(001-1-3)은 같은 안내문을 빨갛게 물들인다.
            description: "한글·영문·숫자만 입력 가능해요. (공백 포함 \(RoomFormLimit.name)자 이내)",
            status: isNameValid ? .normal : .negative,
            identifier: "RoomForm.nameField"
        )
    }

    private var descriptionField: some View {
        MHTextArea(
            descriptionPlaceholder,
            text: $roomDescription,
            heading: "방 설명",
            status: isDescriptionValid ? .normal : .negative,
            identifier: "RoomForm.descriptionField",
            bottomLeading: {
                MHCharacterCounter(count: roomDescription.count, limit: RoomFormLimit.description)
            }
        )
    }

    // MARK: 색상 선택

    private var colorPicker: some View {
        MHSelectionGrid(
            title: "방 색상 선택",
            items: RoomColorPalette.gridItems,
            selectedIndex: selectedColorIndex,
            shape: .roundedSquare,
            identifierPrefix: "RoomForm.color",
            onSelect: onSelectColor
        )
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

#Preview("편집 모드") {
    PreviewHost(
        mode: .edit,
        roomName: "야호",
        roomDescription: "야호호",
        selectedColorIndex: 0,
        showsSkip: false
    )
}

/// 검증 결과를 손으로 넘기지 않고 실제 `RoomFormState` 에서 뽑는다 — 프리뷰가 reducer 규칙과 어긋나지 않게.
private struct PreviewHost: View {
    @State var state = RoomFormState()
    var showsSkip: Bool = true

    var showsBack: Bool = true

    init(
        mode: RoomFormMode = .create,
        roomName: String,
        roomDescription: String,
        selectedColorIndex: Int?,
        dialog: RoomFormDialog? = nil,
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
        self._state = State(initialValue: state)
        self.showsSkip = showsSkip
        self.showsBack = showsBack
    }

    var body: some View {
        RoomFormContent(
            mode: state.mode,
            roomName: $state.roomName,
            roomDescription: $state.roomDescription,
            selectedColorIndex: state.selectedColorIndex,
            isNameValid: state.isNameValid,
            isDescriptionValid: state.isDescriptionValid,
            isSubmitEnabled: state.isSubmitEnabled,
            dialog: state.dialog,
            onSelectColor: { state.selectedColorIndex = $0 },
            onSubmit: { state.dialog = .saveConfirm },
            onDismissDialog: { state.dialog = nil },
            onConfirmSubmit: { state.dialog = nil },
            onConfirmCancel: { state.dialog = nil },
            onBack: showsBack ? { state.dialog = .cancelConfirm } : nil,
            onSkip: showsSkip ? {} : nil
        )
    }
}
