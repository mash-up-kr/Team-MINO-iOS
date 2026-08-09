import DesignSystem
import Domain
import MVI
import SwiftUI

/// 방 리스트 바텀 시트 화면. Figma Frame 198(node 2236:45798) — 저장 탭 진입 화면.
///
/// 지도 위에 겹쳐 뜨는 비모달 시트(`MHBottomSheet`)로, 지도가 아직 없어 뒤는 중립 배경으로 채운다.
/// 헤더(타이틀 + 추가 버튼)·필터(``MHCategory``)는 시트 상단에 고정하고, 방 카드 목록만
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
            // store 없을 때만 실행 → 1회 생성 보장. 배경은 시트 뒤 중립 플레이스홀더 유지.
            Color.mhBackgroundNormalAlternative
                .ignoresSafeArea()
                .task { store = coordinator.makeRoomListStore() }
        }
    }
}

// MARK: - RoomListLoadedView

/// store 가 준비된 뒤의 실제 시트. store.state 를 읽어 그리고, 진입 시 `.load` 를 보낸다.
private struct RoomListLoadedView: View {
    let store: RoomListStore
    @State private var detent: MHBottomSheetDetent = .medium

    var body: some View {
        ZStack {
            // 지도 미도입 — 시트 뒤를 채우는 중립 플레이스홀더 배경.
            Color.mhBackgroundNormalAlternative
                .ignoresSafeArea()

            // low(peek) 는 그래버(30) + 헤더(60) = 90pt 만 보이게(Figma 003-1-1 peek). 하단 safe-area 는 MHBottomSheet 가 보정.
            // TODO(flicker): low→medium 전환 시 헤더 "+" 버튼(MHIconButton)이 4-5회 깜박임 — 다른 로컬에서 진단·수정 예정.
            //   가설: 전환 스프링 중 greedy 카드 스크롤뷰가 펴지며 시트 콘텐츠가 반복 리렌더.
            //   재현: detent 를 .low 로 시작해 .task 지연 후 .medium 자동전환 + simctl recordVideo → ffmpeg 프레임 추출.
            //   관련: MHBottomSheet.swift .animation(value: detent) / MHBottomSheetScrollView offset preference.
            MHBottomSheet(detent: $detent, lowPeek: 112, mediumFraction: 0.5) {
                RoomListContentView(
                    rooms: store.state.rooms.map(RoomListItem.init(from:)),
                    filterSelection: filterBinding
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
}

// MARK: - RoomListContentView

/// `MHBottomSheet` 콘텐츠. 헤더·필터는 고정, 카드 목록만 스크롤된다.
///
/// Store 를 모르는 순수 뷰 — 표시 모델(`rooms`)과 필터 선택(`filterSelection`)을 입력으로만 받는다.
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
                    // 도메인 안정 ID(room.id) 사용 — 배열 인덱스는 정렬/필터 시 다른 행을 가리키게 되므로 금지.
                    .accessibilityIdentifier("RoomList.card.\(room.id)")
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("RoomList.cardList")
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
            members: Array(repeating: nil, count: room.users.count)
        )
    }

    private static func thumbnail(for room: Room) -> MHRoomThumbnailKind {
        switch room.type {
        case .personal:
            return .myRoom
        case .shared:
            // TODO: 디자인의 hex↔색 매핑이 확정되면 `room.color` 를 사용한다.
            //       지금은 id 안정 해시로 12색 중 하나를 결정론적으로 고른다.
            let colors = MHRoomThumbnailColor.allCases
            let index = abs(stableHash(room.id)) % colors.count
            return .color(colors[index])
        }
    }
}

/// 실행마다 값이 달라지는 `String.hashValue` 대신 결정론적 해시(테스트·렌더 안정).
private func stableHash(_ string: String) -> Int {
    string.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
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
                RoomListContentView(rooms: .markupSamples, filterSelection: $filter)
            }
        }
    }
    return Host()
}
