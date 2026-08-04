import SwiftUI
import DesignSystem

// MARK: - 방 색상 스와치

/// 색 선택 그리드 한 칸의 채움/테두리 색. 미선택 = fill 채움 + border 테두리, 선택 = border 색으로 통짜 채움 + 체크.
private struct RoomColorSwatch {
    let fill: Color
    let border: Color
}

/// 방 색상 선택 12색. 순서는 피그마 4열×3행 그리드(좌→우, 상→하)와 동일하다.
///
/// 색상은 Figma `Atomic/*` 팔레트를 그대로 쓴다 — 사용자가 고르는 팔레트라 역할이 없어 시맨틱 토큰이 맞지 않는다.
/// 계열마다 밝은 단계가 채움, 진한 단계가 테두리다.
private let roomColorSwatches: [RoomColorSwatch] = [
    RoomColorSwatch(fill: .mhAtomicRed60, border: .mhAtomicRed30),
    RoomColorSwatch(fill: .mhAtomicRedOrange70, border: .mhAtomicRedOrange40),
    RoomColorSwatch(fill: .mhAtomicOrange70, border: .mhAtomicOrange40),
    RoomColorSwatch(fill: .mhAtomicLime80, border: .mhAtomicLime37),
    RoomColorSwatch(fill: .mhAtomicGreen90, border: .mhAtomicGreen60),
    RoomColorSwatch(fill: .mhAtomicCyan90, border: .mhAtomicCyan50),
    RoomColorSwatch(fill: .mhAtomicViolet80, border: .mhAtomicViolet50),
    RoomColorSwatch(fill: .mhAtomicPink90, border: .mhAtomicPink60),
    RoomColorSwatch(fill: .mhAtomicBlue65, border: .mhAtomicBlue40),
    RoomColorSwatch(fill: .mhAtomicBrown70, border: .mhAtomicBrown40),
    RoomColorSwatch(fill: .mhAtomicLightBlue60, border: .mhAtomicLightBlue40),
    RoomColorSwatch(fill: .mhAtomicPurple70, border: .mhAtomicPurple40),
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
    let isCreateEnabled: Bool
    let onSelectColor: (Int) -> Void
    let onCreate: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    private let namePlaceholder = "방 이름을 입력해 주세요."
    private let descriptionPlaceholder = "어떤 장소들을 모으는 방인가요?"
    private let descriptionLimit = 20

    var body: some View {
        VStack(spacing: 0) {
            topNavigation
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
                MHActionArea(main: MHAction("방 생성하기", action: onCreate), sticky: true, safeArea: false)
                    .disabled(!isCreateEnabled)
            }
        }
        .background(Color.mhBackgroundNormalNormal)
    }

    // MARK: Top Navigation

    private var topNavigation: some View {
        ZStack {
            Text("공동방 만들기")
                .mhTypography(.headline2Bold)
                .foregroundStyle(Color.mhLabelStrong)
            HStack {
                Button(action: onBack) {
                    Image(MHIcon.chevronLeft)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.mhLabelNormal)
                }
                Spacer()
                Button(action: onSkip) {
                    Text("건너뛰기")
                        .mhTypography(.label1NormalMedium)
                        .foregroundStyle(Color.mhLabelNormal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            RoundedRectangle(cornerRadius: 20).strokeBorder(Color.mhPrimaryNormal, lineWidth: 1)
        }
    }

    // 색을 고르면 색이 바뀌는 지도 placeholder(실제 지도 에셋 도입 전까지).
    private var mapThumbnail: some View {
        let swatch = selectedColorIndex.flatMap(swatch(at:))
        return RoundedRectangle(cornerRadius: 20)
            .fill(swatch?.fill ?? Color.mhFillNormal)
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
            description: "한글·영문·숫자만 입력 가능해요. (공백 포함 15자 이내)"
        )
    }

    private var descriptionField: some View {
        MHTextArea(
            descriptionPlaceholder,
            text: $roomDescription,
            heading: "방 설명",
            bottomLeading: {
                MHCharacterCounter(count: roomDescription.count, limit: descriptionLimit)
            }
        )
    }

    // MARK: 색상 선택

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("방 색상 선택")
                .mhTypography(.label1NormalBold)
                .foregroundStyle(Color.mhLabelNeutral)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(roomColorSwatches.indices, id: \.self) { index in
                    colorSwatchButton(index)
                }
            }
        }
    }

    private func colorSwatchButton(_ index: Int) -> some View {
        let swatch = roomColorSwatches[index]
        let isSelected = selectedColorIndex == index
        return Button {
            onSelectColor(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? swatch.border : swatch.fill)
                if !isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(swatch.border, lineWidth: 3)
                }
                if isSelected {
                    Image(MHIcon.checkThick)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(Color.mhStaticWhite)
                }
            }
            .frame(width: 70, height: 70)
            .mhShadow(.medium, cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private func swatch(at index: Int) -> RoomColorSwatch? {
        roomColorSwatches.indices.contains(index) ? roomColorSwatches[index] : nil
    }
}

// MARK: - Preview

#Preview("버튼 활성") {
    PreviewHost(
        roomName: "민호야 잘하자",
        roomDescription: "팀 회식 장소 모음",
        selectedColorIndex: 2,
        isCreateEnabled: true
    )
}

#Preview("버튼 비활성") {
    PreviewHost(
        roomName: "",
        roomDescription: "",
        selectedColorIndex: 0,
        isCreateEnabled: false
    )
}

private struct PreviewHost: View {
    @State var roomName: String
    @State var roomDescription: String
    @State var selectedColorIndex: Int?
    let isCreateEnabled: Bool

    var body: some View {
        CreateRoomContent(
            roomName: $roomName,
            roomDescription: $roomDescription,
            selectedColorIndex: selectedColorIndex,
            isCreateEnabled: isCreateEnabled,
            onSelectColor: { selectedColorIndex = $0 },
            onCreate: {},
            onBack: {},
            onSkip: {}
        )
    }
}
