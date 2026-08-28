import DesignSystem
import SwiftUI

/// 이 장소가 중복 저장된 방 목록 바텀시트. Figma `014 저장된 방`(`4170:126144`).
///
/// **Store 를 갖지 않는다.** 목록은 이 시트를 열 수 있게 만든 조건 그 자체라 이미
/// ``PlaceDetailState/savedRooms`` 에 있고(005-1 ⑮ 의 활성 조건), 여기서 다시 받아오면 버튼을
/// 켠 목록과 시트가 그리는 목록이 갈라진다. 하는 일은 받은 목록을 그리고 탭 한 번을 위로
/// 올려 보내는 것뿐이라 상태도 비동기도 없다(``RoomCreationPromptView`` 와 같은 결).
///
/// 딤을 동반한 모달이라 ``MHBottomSheet``(딤 없는 비모달)이 아니라 SwiftUI 네이티브 `.sheet` 에
/// 얹는다 — ``RoomShareSheet`` 와 같은 이유. 띄우는 쪽은 ``ArchiveShellView``.
struct SavedRoomsSheet: View {
    /// `presentationDetents(.height(_:))` 에 넘길 값.
    ///
    /// 시안 시트 높이 442(기획 014 ① "하단의 safe area(60px)포함 높이값 442px")에서 34 를 뺀다.
    /// 시안이 말하는 하단 60 중 **홈 인디케이터 34** 만 iOS 가 따로 확보하는 몫이고(시안
    /// `4170:126144` 의 Home Bar 는 y=778.5·h=34 로 그 60 안에 들어 있다), `.height` 는 하단
    /// 안전영역 **위쪽** 높이라 그만큼 빼야 화면에서 442 가 된다 —
    /// ``RoomShareSheetMetrics`` 와 같은 유도다.
    /// 남는 26 은 목록 아래 여백으로 그대로 산다(``footer`` 가 홈 인디케이터까지 함께 덮는다).
    static let detentHeight: CGFloat = 442 - 34

    /// 스크롤 영역 고정 높이(기획 014 ① "스크롤 영역은 312px(고정값)을 유지한다").
    /// 방이 한 칸뿐이어도 이만큼을 지켜 시트 높이가 목록에 따라 달라지지 않는다.
    private static let listHeight: CGFloat = 312

    let rooms: [RoomListItem]
    /// 방 카드 탭 — "클릭 시, 해당 방의 장소상세로 이동한다"(기획 014 ②).
    let onSelect: (RoomListItem.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            grabber
            title
            list
            footer
        }
        .background(.mhBackgroundElevatedNormal)
        // 하단 안전영역까지 직접 그린다 — 그래야 VStack 이 시안과 같은 442 를 받고, 시안의
        // 하단 60 블록(`4170:126318`)이 홈 인디케이터를 덮는 모양 그대로 나온다.
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("SavedRooms.sheet")
    }

    // 그래버 — h30(py12) 안에 38×4 바. Figma `4170:126147`.
    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
    }

    // 제목 — px20 + pb12, Heading 2/Bold. Figma `4170:126149`.
    private var title: some View {
        Text("저장된 방")
            .mhTypography(.heading2Bold)
            .foregroundStyle(.mhLabelNormal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .accessibilityIdentifier("SavedRooms.title")
    }

    // 방 목록 — 고정 312. Figma `4170:126152`.
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    card(room)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: Self.listHeight)
        .accessibilityIdentifier("SavedRooms.list")
    }

    /// 시안의 하단 블록(`4170:126318`) — 목록과 홈 인디케이터를 가르는 1px 선 + 흰 면.
    /// 높이를 고정하지 않고 남은 만큼 차지한다: 그래버 30 + 제목 40 + 목록 312 = 382 이므로
    /// 442 − 382 = 60 이 그대로 떨어진다.
    private var footer: some View {
        Rectangle()
            .fill(.mhBackgroundNormalNormal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.mhLineNormalNeutral)
                    .frame(height: 1)
            }
    }

    /// 방 한 줄 — Figma `Card_Room`(`4170:126154`)에 오른쪽 셰브런. 메모·멤버 아바타는 이 화면에서
    /// 감춰져 있어 넘기지 않는다(``MHRoomCard`` 가 둘 다 선택 인자다).
    private func card(_ room: RoomListItem) -> some View {
        Button {
            onSelect(room.id)
        } label: {
            HStack(spacing: 12) {
                MHRoomCard(title: room.title, placeCount: room.placeCount, thumbnail: room.thumbnail)
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("SavedRooms.room.\(room.id)")
        .accessibilityLabel("\(room.title), 장소 \(room.placeCount)개")
    }

    /// Figma `Icon/Normal/Chevron Right` 18. DS 아이콘에는 왼쪽(`chevronLeft`)만 있는데 좌우
    /// 대칭 도형이라 뒤집어 쓴다 — `chevronRight` 에셋이 들어오면 이 뒤집기를 지운다.
    private var chevron: some View {
        Image(.chevronLeft)
            .resizable()
            .frame(width: 18, height: 18)
            .scaleEffect(x: -1)
            .foregroundStyle(.mhLabelAlternative)
    }
}

#Preview("저장된 방 시트") {
    SavedRoomsSheet(rooms: .markupSamples, onSelect: { _ in })
        .frame(height: SavedRoomsSheet.detentHeight)
}
