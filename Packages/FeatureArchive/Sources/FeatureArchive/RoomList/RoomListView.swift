import DesignSystem
import Domain
import MVI
import SwiftUI

/// 방 리스트 바텀 시트 화면. Figma Frame 198(node 2236:45798) — 저장 탭 진입 화면.
/// peek 상태는 Figma `003-1-1 peek`(node 1604:100087).
///
/// 배경 지도(``ArchiveMapLayer``) 위에 상단 필터바(``MHFilterBar``)와 비모달 시트(`MHBottomSheet`)가
/// 겹쳐 뜬다. 헤더(타이틀 + 추가 버튼)·필터(``MHCategory``)는 시트 상단에 고정하고, 방 카드 목록만
/// ``MHBottomSheetScrollView`` 로 스크롤한다.
///
/// Store 는 ``ArchiveCoordinator`` 팩토리로 `.task` 에서 1회 lazy 생성한다(MemberHome 패턴).
/// 진입 시 `.load` 로 방 목록을 불러오고, `store.state.rooms`(도메인 `Room`)를 표시 모델
/// ``RoomListItem`` 으로 매핑해 순수 뷰 ``RoomListContentView`` 에 주입한다.
struct RoomListView: View {
    private let coordinator: ArchiveCoordinator
    @State private var store: RoomListStore?

    init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            RoomListLoadedView(store: store)
        } else {
            // store 없을 때만 실행 → 1회 생성 보장. 배경은 로드 후와 같은 지도라 전환이 튀지 않는다.
            ArchiveMapLayer()
                .task { store = coordinator.makeRoomListStore() }
        }
    }
}

// MARK: - RoomListLoadedView

/// store 가 준비된 뒤의 실제 시트. store.state 를 읽어 그리고, 진입 시 `.load` 를 보낸다.
private struct RoomListLoadedView: View {
    let store: RoomListStore
    @State private var detent: MHBottomSheetDetent = .medium

    /// 디자인 정책(003-2): half 는 공동방 수와 무관하게 헤더+칩+개인방 카드 합산 높이(고정)를 유지한다
    /// (바텀 네비 제외). 스펙 이상치는 그래버(30)+헤더(60)+칩(50)+카드(104)=244 이지만,
    /// 실제 그래버 간격 영역이 더 커(~54) 카드가 탭바에 잘려 실측 보정값 268 을 쓴다(lowPeek 112 와 동일 논리).
    private let mediumPeek: CGFloat = 268

    var body: some View {
        ZStack {
            ArchiveMapLayer()

            // Figma `Chip_Room`(node 2387:121989) — 지도 위, 시트 아래 레이어. 상단 safe area 바로 밑에 붙는다.
            // MHFilterBar 가 padding(top 20 / bottom 12 / horizontal 20)을 내장하므로 화면단에서 더하지 않는다.
            VStack(spacing: 0) {
                MHFilterBar(
                    sortOptions: roomOptions,
                    selectedSort: roomFilterBinding,
                    categories: Self.categories,
                    selectedCategory: categoryBinding
                )
                .accessibilityIdentifier("RoomList.filterBar")
                Spacer(minLength: 0)
            }

            // low(peek) 는 그래버(30) + 헤더(60) 만, medium 은 카드 영역까지 — 둘 다 콘텐츠 pt 기반(MHBottomSheet 가 하단 safe-area 보정).
            MHBottomSheet(detent: $detent, lowPeek: 112, mediumPeek: mediumPeek) {
                RoomListContentView(
                    rooms: store.state.rooms.map(RoomListItem.init(from:)),
                    showEmptyState: !store.state.rooms.contains { $0.type == .shared },
                    isFull: detent == .full,
                    filterSelection: filterBinding,
                    onClose: { withAnimation(.spring(duration: 0.3)) { detent = .medium } }
                )
            }
            .accessibilityIdentifier("RoomList.sheet")
        }
        .task { store.send(.load) }
    }

    private var filterBinding: Binding<Int> {
        Binding(
            get: { store.state.filter },
            set: { store.send(.selectFilter($0)) }
        )
    }

    // MARK: - 상단 필터바

    /// 디자인에서 보이는 카테고리 3종. 가로 스크롤 칩이라 항목이 늘 수 있으나, 확장은 데이터가 붙을 때 함께 정한다.
    private static let categories = ["전체", "카페", "음식점"]

    /// 좌측 드롭다운 = 방 선택(node 이름 `Chip_Room`). 첫 항목은 방 전체를 뜻하는 "전체".
    private var roomOptions: [String] {
        ["전체"] + store.state.rooms.map(\.name)
    }

    private var roomFilterBinding: Binding<Int> {
        Binding(
            get: { min(store.state.roomFilter, roomOptions.count - 1) },   // 방 목록이 줄어도 인덱스가 범위를 벗어나지 않게
            set: { store.send(.selectRoomFilter($0)) }
        )
    }

    private var categoryBinding: Binding<Int> {
        Binding(
            get: { store.state.categoryFilter },
            set: { store.send(.selectCategory($0)) }
        )
    }
}

// MARK: - RoomListContentView

/// `MHBottomSheet` 콘텐츠. 헤더·필터는 고정, 카드 목록만 스크롤된다.
///
/// Store 를 모르는 순수 뷰 — 표시 모델(`rooms`)과 필터 선택(`filterSelection`)을 입력으로만 받는다.
struct RoomListContentView: View {
    let rooms: [RoomListItem]
    let showEmptyState: Bool
    let isFull: Bool
    @Binding var filterSelection: Int
    var onClose: (() -> Void)?

    private let filterItems = ["전체", "최근 저장 순", "코멘트 순"]

    var body: some View {
        VStack(spacing: 0) {
            header
            filter
            cardList
        }
    }

    // Figma: h60, px20. full 상태에서 "×" 닫기 버튼 추가(gap 8, Figma node 2661:156812).
    private var header: some View {
        HStack(spacing: 0) {
            Text("방 리스트")
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .accessibilityIdentifier("RoomList.title")
            Spacer()
            HStack(spacing: 8) {
                MHIconButton(icon: .plus, accessibilityLabel: "방 추가") {}
                    .accessibilityIdentifier("RoomList.addButton")
                if isFull {
                    MHIconButton(icon: .close, accessibilityLabel: "시트 접기") {
                        onClose?()
                    }
                    .accessibilityIdentifier("RoomList.closeButton")
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    // Figma Frame 304: h50, 좌우 padding 20, Category y=9 h32(size .medium).
    //
    // 개별 칩(전체/최근 저장 순/코멘트 순)은 `MHCategory`/`MHChip` 내부 Button 이라 화면단에서
    // identifier 를 부여할 수 없다(DS 컴포넌트가 접두사·식별자 훅을 노출하지 않음) — AXe 는 칩의
    // 기본 accessibility label(칩 텍스트, 예: "전체")로 탭한다. 선택 "상태"는 개별 칩에 trait/value 가
    // 없어 읽을 수 없으므로, 컨테이너(`RoomList.filter`)에 현재 선택된 칩 텍스트를
    // `accessibilityValue` 로 노출해 자동화가 선택 상태를 검증할 수 있게 한다.
    private var filter: some View {
        MHCategory(filterItems, selection: $filterSelection, variant: .normal, size: .medium, horizontalPadding: true)
            .frame(height: 50)
            .accessibilityIdentifier("RoomList.filter")
            .accessibilityValue(filterItems[filterSelection])
    }

    // Figma Frame 460: 좌우 padding 20. 카드만 스크롤 영역(헤더·필터는 고정).
    private var cardList: some View {
        MHBottomSheetScrollView {
            VStack(spacing: 0) {
                ForEach(rooms, id: \.id) { room in
                    MHRoomCard(
                        title: room.title,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        thumbnail: room.thumbnail,
                        members: room.members
                    )
                    .accessibilityIdentifier("RoomList.card.\(room.id)")
                }
                if showEmptyState {
                    emptyStateView
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("RoomList.cardList")
    }

    // Figma node 2236:45731 — 공동방이 없을 때 카드 아래에 보이는 빈 상태.
    // Figma 에선 flex-1 + justify-center 로 남은 영역 중앙 정렬. 위아래 Spacer 로 남은
    // 영역을 채워 수직 중앙을 잡되, minHeight 만 고정해 문구가 길어지면 잘리지 않고 늘어난다.
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 24) {
                Image("emptyRoomIllustration", bundle: .module)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("공동방을 생성해보세요!")
                        .mhTypography(.title3Bold)
                        .foregroundStyle(.mhPrimaryNormal)

                    Text("\"저번에 말한 거기가 어디였지?\"\n더 이상 묻지 마세요.")
                        .mhTypography(.label1NormalRegular)
                        .foregroundStyle(.mhLabelAlternative)
                        .multilineTextAlignment(.center)
                }

                MHButton("공동방 만들기", size: .medium, leadingIcon: .plus) {
                    // TODO: 공동방 생성 플로우 연결
                }
                .accessibilityIdentifier("RoomList.createRoomButton")
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 444)   // Figma 빈 상태 영역 높이(스크롤 영역 548 − 카드 ~104), 내용이 길면 확장
        .accessibilityIdentifier("RoomList.emptyState")
    }
}

// MARK: - RoomListItem (표시 모델)

/// 마크업 표시 모델. 도메인 `Room` 을 카드가 그릴 값으로 변환한 것이다.
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

// MARK: - Room → RoomListItem 매핑

extension RoomListItem {
    /// 도메인 `Room` → 카드 표시 모델. 아바타 이미지는 아직 없어 개수만큼 `nil` 플레이스홀더로 채운다.
    init(from room: Room) {
        self.init(
            id: room.id,
            title: room.name,
            memo: room.description,
            placeCount: room.pinCount,
            thumbnail: Self.thumbnail(for: room),
            members: Array(repeating: nil, count: min(room.users.count, 5))
        )
    }

    private static func thumbnail(for room: Room) -> MHRoomThumbnailKind {
        switch room.type {
        case .personal:
            return .myRoom
        case .shared:
            // 백엔드 `room.color`(방 생성 시 고른 색)를 hue 로 팔레트 12색에 매핑.
            // 색을 못 뽑으면(무채색·형식오류) my-room 썸네일로 폴백.
            return MHRoomThumbnailColor(roomColorHex: room.color).map { .color($0) } ?? .myRoom
        }
    }
}

// MARK: - 마크업 프리뷰 샘플

extension [RoomListItem] {
    /// 프리뷰용 정적 샘플. "내 장소"(my-room)·공유 방(색 썸네일) 혼합.
    static var markupSamples: [RoomListItem] {
        [
            RoomListItem(id: "me", title: "내 장소", placeCount: 0, thumbnail: .myRoom, members: [nil]),
            RoomListItem(
                id: "food",
                title: "우리 동네 맛집",
                memo: "친구들이랑 같이 저장하는 곳",
                placeCount: 12,
                thumbnail: .color(.orange),
                members: [nil, nil, nil]
            ),
            RoomListItem(
                id: "cafe",
                title: "가고싶은 카페",
                memo: "분위기 좋은 카페 모음",
                placeCount: 5,
                thumbnail: .color(.blue),
                members: [nil, nil]
            ),
        ]
    }
}

// MARK: - Preview

#Preview("RoomList") {
    struct Host: View {
        @State private var filter = 0
        var body: some View {
            ZStack {
                Color.mhBackgroundNormalAlternative.ignoresSafeArea()
                RoomListContentView(rooms: .markupSamples, showEmptyState: false, isFull: false, filterSelection: $filter)
            }
        }
    }
    return Host()
}

#Preview("RoomList — Empty") {
    struct Host: View {
        @State private var filter = 0
        var body: some View {
            ZStack {
                Color.mhBackgroundNormalAlternative.ignoresSafeArea()
                RoomListContentView(
                    rooms: [RoomListItem(id: "me", title: "내 장소", placeCount: 0, thumbnail: .myRoom, members: [nil])],
                    showEmptyState: true,
                    isFull: true,
                    filterSelection: $filter
                )
            }
        }
    }
    return Host()
}
