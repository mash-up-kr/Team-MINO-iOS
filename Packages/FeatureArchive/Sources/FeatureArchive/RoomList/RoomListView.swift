import DesignSystem
import SwiftUI

/// 방 리스트 바텀 시트 화면. Figma Frame 198(node 2236:45798) — 저장 탭 진입 화면.
///
/// 지도 위에 겹쳐 뜨는 비모달 시트(`MHBottomSheet`)로, 지도가 아직 없어 뒤는 중립 배경으로 채운다.
/// 헤더(타이틀 + 추가 버튼)·필터(``MHCategory``)는 시트 상단에 고정하고, 방 카드 목록만
/// ``MHBottomSheetScrollView`` 로 스크롤한다.
///
/// Store 는 붙이지 않는다(MARKUP 증분) — ``RoomListContentView`` 가 데이터를 입력으로 받는 순수 뷰라
/// IMPL 이 이 자리에 `store.state`/`store.send` 를 그대로 끼워 넣을 수 있다.
struct RoomListView: View {
    @State private var detent: MHBottomSheetDetent = .medium
    @State private var filterSelection = 0
    private let rooms: [RoomListItem]

    /// - Parameter rooms: 표시할 방 목록. 기본값은 마크업 확인용 샘플(``RoomListItem/markupSamples``).
    ///   IMPL 은 이 파라미터에 store 의 실제 데이터를 주입한다.
    // TODO(IMPL): store 데이터로 교체 시 이 기본값 제거
    init(rooms: [RoomListItem] = .markupSamples) {
        self.rooms = rooms
    }

    var body: some View {
        ZStack {
            // 지도 미도입 — 시트 뒤를 채우는 중립 플레이스홀더 배경.
            Color.mhBackgroundNormalAlternative
                .ignoresSafeArea()

            MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.5) {
                RoomListContentView(rooms: rooms, filterSelection: $filterSelection)
            }
            .accessibilityIdentifier("RoomList.sheet")
        }
    }
}

// MARK: - RoomListContentView

/// `MHBottomSheet` 콘텐츠. 헤더·필터는 고정, 카드 목록만 스크롤된다.
///
/// Store 를 모르는 순수 뷰 — 데이터(`rooms`)와 필터 선택(`filterSelection`)을 입력으로만 받는다.
/// IMPL 은 이 시그니처를 유지한 채 `rooms: store.state.rooms`, `filterSelection: $store.state.filter`
/// (또는 `Binding` 어댑터)로 교체하면 된다.
struct RoomListContentView: View {
    let rooms: [RoomListItem]
    @Binding var filterSelection: Int

    private let filterItems = ["전체", "최근 저장 순", "코멘트 순"]

    var body: some View {
        VStack(spacing: 0) {
            header
            filter
            cardList
        }
    }

    // Figma Frame 303: h60, 좌우 padding 20, 세로중앙, justify-between.
    private var header: some View {
        HStack(spacing: 0) {
            Text("방 리스트")
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .accessibilityIdentifier("RoomList.title")
            Spacer()
            MHIconButton(icon: .plus, accessibilityLabel: "방 추가") {}
                .accessibilityIdentifier("RoomList.addButton")
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    // Figma Frame 304: h50, 좌우 padding 20, Category y=9 h32(size .medium).
    private var filter: some View {
        MHCategory(filterItems, selection: $filterSelection, variant: .normal, size: .medium, horizontalPadding: true)
            .frame(height: 50)
            .accessibilityIdentifier("RoomList.filter")
    }

    // Figma Frame 460: 좌우 padding 20. 카드만 스크롤 영역(헤더·필터는 고정).
    private var cardList: some View {
        MHBottomSheetScrollView {
            VStack(spacing: 0) {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                    MHRoomCard(
                        title: room.title,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        thumbnail: room.thumbnail,
                        members: room.members
                    )
                    .accessibilityIdentifier("RoomList.card.\(index)")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - RoomListItem

/// 마크업 로컬 표시 모델. Domain 엔티티가 아니다 — IMPL 이 실제 도메인 타입으로 매핑/교체한다.
struct RoomListItem: Identifiable, Equatable {
    let id: String
    let title: String
    let memo: String?
    let placeCount: Int
    let thumbnail: MHRoomThumbnailKind
    let members: [Image?]

    init(
        id: String,
        title: String,
        memo: String? = nil,
        placeCount: Int,
        thumbnail: MHRoomThumbnailKind,
        members: [Image?] = []
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.placeCount = placeCount
        self.thumbnail = thumbnail
        self.members = members
    }

    // members 는 [Image?] 라 Equatable 이 아니다(Image 가 값 비교를 지원하지 않음) — 개수만 비교해
    // "멤버 수가 바뀐 갱신"은 감지하고, 아바타 이미지 자체의 변경은 이 비교로 감지하지 않는다(허용된 근사).
    static func == (lhs: RoomListItem, rhs: RoomListItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.memo == rhs.memo
            && lhs.placeCount == rhs.placeCount && lhs.thumbnail == rhs.thumbnail
            && lhs.members.count == rhs.members.count
    }
}

extension [RoomListItem] {
    /// 마크업 확인용 정적 샘플. "내 장소" 카드는 Figma 정합 대상(memo 없음·아바타 1개·my-room 썸네일)이고,
    /// 나머지는 리스트 성격을 보이기 위해 덧붙인 샘플(shared 방·색 썸네일·memo 있음)이다 — figma 정합 대상 아님.
    static var markupSamples: [RoomListItem] {
        [
            RoomListItem(title: "내 장소", placeCount: 0, thumbnail: .myRoom, members: [nil]),
            RoomListItem(
                title: "우리 동네 맛집",
                memo: "친구들이랑 같이 저장하는 곳",
                placeCount: 12,
                thumbnail: .color(.orange),
                members: [nil, nil, nil]
            ),
            RoomListItem(
                title: "가고싶은 카페",
                memo: "분위기 좋은 카페 모음",
                placeCount: 5,
                thumbnail: .color(.blue),
                members: [nil, nil]
            ),
        ]
    }
}

private extension RoomListItem {
    init(
        title: String,
        memo: String? = nil,
        placeCount: Int,
        thumbnail: MHRoomThumbnailKind,
        members: [Image?] = []
    ) {
        self.init(id: title, title: title, memo: memo, placeCount: placeCount, thumbnail: thumbnail, members: members)
    }
}

// MARK: - Preview

#Preview("RoomListView") {
    RoomListView()
}
