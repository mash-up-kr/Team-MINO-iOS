import SwiftUI
import DesignSystem

// MARK: - 방 색상 스와치

/// 방 색상 선택 12색. 순서는 피그마 4열×3행 그리드(좌→우, 상→하)와 동일하다.
///
/// 색상은 Figma `Atomic/*` 팔레트를 그대로 쓴다 — 사용자가 고르는 팔레트라 역할이 없어 시맨틱 토큰이 맞지 않는다.
/// 계열마다 밝은 단계가 채움, 진한 단계가 테두리다.
private let roomColorSwatches: [MHSelectionGridItem] = [
    .color(fill: .mhRed60, border: .mhRed30),
    .color(fill: .mhRedOrange70, border: .mhRedOrange40),
    .color(fill: .mhOrange70, border: .mhOrange40),
    .color(fill: .mhLime80, border: .mhLime37),
    .color(fill: .mhGreen90, border: .mhGreen60),
    .color(fill: .mhCyan90, border: .mhCyan50),
    .color(fill: .mhViolet80, border: .mhViolet50),
    .color(fill: .mhPink90, border: .mhPink60),
    .color(fill: .mhBlue65, border: .mhBlue40),
    .color(fill: .mhBrown70, border: .mhBrown40),
    .color(fill: .mhLightBlue60, border: .mhLightBlue40),
    .color(fill: .mhPurple70, border: .mhPurple40),
]

// MARK: - CreateRoomContent

/// "공동방 만들기" 화면의 순수 마크업. Store·Coordinator 를 모른다 — 값과 클로저만 받는다.
///
/// 카드 안 지도 썸네일은 실제 지도 에셋이 아직 없어 선택된 색으로 틴트되는 placeholder 로 그린다
/// (색을 고르면 지도 색이 바뀌는 확정 동작을 반영하기 위함). 지도 에셋이 붙으면 교체 대상이다.
struct CreateRoomContent: View {
    @Binding var roomName: String
    @Binding var roomDescription: String
    let selectedColorIndex: Int?
    let isNameValid: Bool
    let isDescriptionValid: Bool
    let isCreateEnabled: Bool
    let dialog: CreateRoomDialog?
    let onSelectColor: (Int) -> Void
    let onCreate: () -> Void
    let onBack: () -> Void
    let onDismissDialog: () -> Void
    let onConfirmCreate: () -> Void
    let onConfirmCancel: () -> Void
    /// `nil` 이면 상단바에 건너뛰기 버튼을 그리지 않는다 — 건너뛸 수 없는 진입점(방리스트 등)을 위해.
    let onSkip: (() -> Void)?

    private let namePlaceholder = "방 이름을 입력해 주세요."
    private let descriptionPlaceholder = "어떤 장소들을 모으는 방인가요?"

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: "공동방 만들기", onBack: onBack, onSkip: onSkip)
            ScrollView {
                VStack(spacing: 30) {
                    previewCard
                    nameField
                    descriptionField
                    colorPicker
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            // 액션 영역을 VStack 자식으로 두면 키보드가 올라올 때 MHActionArea 의 하단 안전영역 측정에
            // 키보드 높이가 섞여 스크롤뷰가 찌그러진다. safeAreaInset 으로 붙여 키보드 회피를 맡긴다.
            .safeAreaInset(edge: .bottom) {
                MHActionArea(main: MHAction("방 생성하기", action: onCreate), sticky: true, safeArea: false)
                    .disabled(!isCreateEnabled)
            }
        }
        .background(Color.mhBackgroundNormalNormal)
        // 방 설명(MHTextArea)은 리턴키가 개행이라 리턴키로 못 닫는다. 스크롤 해제·툴바 '완료' 와 함께
        // 여백 탭도 열어 둔다 — 키보드가 하단을 가리면 방 색상 그리드에 접근 자체가 안 된다(이슈 #93).
        .mhDismissKeyboardOnTap()
        .mhDialog(item: .constant(dialog)) { confirmDialog($0) }
    }

    // MARK: 확인 다이얼로그 (디자인 001-1-4)

    private func confirmDialog(_ dialog: CreateRoomDialog) -> MHDialog {
        switch dialog {
        case .saveConfirm:
            MHDialog(
                title: "공동방을 저장하시겠어요?",
                message: "공동방 편집에서 설정을 변경할 수 있어요.",
                cancel: MHAction("취소", action: onDismissDialog),
                confirm: MHAction("저장하기", action: onConfirmCreate)
            )
        case .cancelConfirm:
            // 문구는 Figma 원문 그대로다("공동방을 만들기를"). 오타로 보이지만 임의로 고치지 않는다.
            MHDialog(
                title: "공동방을 만들기를 취소하시겠어요?",
                message: "저장탭에서 공동방을 생성할 수 있어요",
                cancel: MHAction("취소", action: onDismissDialog),
                confirm: MHAction("나가기", action: onConfirmCancel)
            )
        }
    }

    // MARK: 미리보기 카드

    private var previewCard: some View {
        HStack(spacing: 12) {
            mapThumbnail
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
        .accessibilityIdentifier("CreateRoom.previewCard")
    }

    // 색을 고르면 색이 바뀌는 지도 placeholder(실제 지도 에셋 도입 전까지).
    private var mapThumbnail: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(selectedFillColor ?? Color.mhFillNormal)
            .frame(width: 92, height: 92)
            .overlay {
                Image(MHIcon.pinFill)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.mhStaticWhite)
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
            description: "한글·영문·숫자만 입력 가능해요. (공백 포함 \(CreateRoomLimit.name)자 이내)",
            status: isNameValid ? .normal : .negative,
            identifier: "CreateRoom.nameField"
        )
    }

    private var descriptionField: some View {
        MHTextArea(
            descriptionPlaceholder,
            text: $roomDescription,
            heading: "방 설명",
            status: isDescriptionValid ? .normal : .negative,
            identifier: "CreateRoom.descriptionField",
            bottomLeading: {
                MHCharacterCounter(count: roomDescription.count, limit: CreateRoomLimit.description)
            }
        )
    }

    // MARK: 색상 선택

    private var colorPicker: some View {
        MHSelectionGrid(
            title: "방 색상 선택",
            items: roomColorSwatches,
            selectedIndex: selectedColorIndex,
            shape: .roundedSquare,
            identifierPrefix: "CreateRoom.color",
            onSelect: onSelectColor
        )
    }

    /// 선택된 칸의 채움색 — 지도 썸네일 틴트에 쓴다.
    private var selectedFillColor: Color? {
        guard let selectedColorIndex, roomColorSwatches.indices.contains(selectedColorIndex),
              case .color(let fill, _) = roomColorSwatches[selectedColorIndex] else { return nil }
        return fill
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

#Preview("건너뛰기 없음") {
    PreviewHost(roomName: "민호야 잘하자", roomDescription: "팀 회식 장소 모음", selectedColorIndex: 2, showsSkip: false)
}

/// 검증 결과를 손으로 넘기지 않고 실제 `CreateRoomState` 에서 뽑는다 — 프리뷰가 reducer 규칙과 어긋나지 않게.
private struct PreviewHost: View {
    @State var state = CreateRoomState()
    var showsSkip: Bool = true

    init(
        roomName: String,
        roomDescription: String,
        selectedColorIndex: Int?,
        dialog: CreateRoomDialog? = nil,
        showsSkip: Bool = true
    ) {
        var state = CreateRoomState()
        state.roomName = roomName
        state.roomDescription = roomDescription
        state.selectedColorIndex = selectedColorIndex
        state.dialog = dialog
        self._state = State(initialValue: state)
        self.showsSkip = showsSkip
    }

    var body: some View {
        CreateRoomContent(
            roomName: $state.roomName,
            roomDescription: $state.roomDescription,
            selectedColorIndex: state.selectedColorIndex,
            isNameValid: state.isNameValid,
            isDescriptionValid: state.isDescriptionValid,
            isCreateEnabled: state.isCreateEnabled,
            dialog: state.dialog,
            onSelectColor: { state.selectedColorIndex = $0 },
            onCreate: { state.dialog = .saveConfirm },
            onBack: { state.dialog = .cancelConfirm },
            onDismissDialog: { state.dialog = nil },
            onConfirmCreate: { state.dialog = nil },
            onConfirmCancel: { state.dialog = nil },
            onSkip: showsSkip ? {} : nil
        )
    }
}
