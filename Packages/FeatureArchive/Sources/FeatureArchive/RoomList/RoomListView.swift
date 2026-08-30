import DesignSystem
import Domain
import MVI
import ProfileSetupUI
import RoomCreationUI
import SwiftUI

struct RoomListView: View {
    let store: RoomListStore
    let isFull: Bool
    let onCollapse: () -> Void

    var body: some View {
        RoomListContentView(
            rooms: store.state.rooms.map(RoomListItem.init(from:)),
            showEmptyState: !store.state.hasSharedRoom,
            isFull: isFull,
            filterSelection: filterBinding,
            onClose: onCollapse,
            onSelectRoom: selectRoom,
            onCreateRoom: { store.send(.tapCreateRoom) }
        )
    }

    private func selectRoom(_ id: RoomListItem.ID) {
        guard let room = store.state.rooms.first(where: { $0.id == id }) else { return }
        store.send(.tapRoom(room))
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
    let showEmptyState: Bool
    let isFull: Bool
    @Binding var filterSelection: Int
    var onClose: (() -> Void)?
    var onSelectRoom: ((RoomListItem.ID) -> Void)?
    /// 빈 상태 CTA 와 헤더 "+" 가 함께 쓰는 방 만들기 진입.
    var onCreateRoom: () -> Void = {}

    private static let filterItems = ["전체", "최근 저장 순", "코멘트 순"]

    /// 시안 `003-1`·`003-2` 실측. **시트가 드러내는 높이(003-1 ②③ · 003-2 ①②)의 단일 출처**다 —
    /// `ArchiveShellView` 가 `MHBottomSheet` 에 넘기는 peek 값이 여기서 나온다.
    ///
    /// half 숫자가 왜 그 값인지가 여기서 드러난다. 시안은 합계만 적어 두었는데, 세 값이 모두
    /// 조각의 합으로 딱 떨어진다 — **그래버 30 + 헤더 70 + 칩 52 = 152** 를 공통으로 깔고
    /// 카드(104)를 몇 장 드러내느냐로만 갈린다(256 / 360 / 380).
    ///
    /// 그래서 숫자를 손으로 적지 않고 조각의 합으로 둔다 — 헤더나 칩 높이를 고치면 세 값이 함께
    /// 따라가고, 어긋나면 `RoomListMetricTests` 가 잡는다.
    enum Metric {
        /// Figma `2661:157261` Frame 303.
        static let headerHeight: CGFloat = 70
        /// 타이틀·아이콘 버튼 아래 남는 여백(둘 다 y=52 에서 끝난다).
        static let headerBottomPadding: CGFloat = 18
        /// Figma `2661:157267` Frame 305 — 칩 32 + 아래 여백 20.
        static let filterHeight: CGFloat = 52
        /// 방 카드 한 장. Figma `2661:157271` Card_Room 335×104 (``MHRoomCard`` 렌더 높이와 같다).
        static let roomCardHeight: CGFloat = 104
        /// ``MHBottomSheet`` 이 시트 맨 위에 그리는 그래버 영역. 그 컴포넌트의 private 값을
        /// 받아 적은 것이라 저쪽이 바뀌면 여기도 함께 고쳐야 한다.
        static let grabberHeight: CGFloat = 30

        /// 카드 목록 위에 늘 깔리는 부분(그래버 + 헤더 + 칩) = 152.
        static let chromeHeight: CGFloat = grabberHeight + headerHeight + filterHeight
        /// 003-2 ② — 카드가 3장 이상일 때 세 번째 카드가 드러나는 높이(380 − 360).
        /// "스크롤 어포던스를 위해 3번째 카드는 짤리게 보여진다".
        static let thirdCardPeek: CGFloat = 20

        /// 003-1 ② peek — "88px(고정값) 높이를 유지한다 … 헤더만 표시한다".
        /// 그래버 30 + 헤더 70 = 100 중 아래 12 가 잘리는 값이라 조각의 합이 아니라 시안 값 그대로다.
        static let peek: CGFloat = 88

        /// half — 드러낼 카드 수로 갈린다(003-1 ③ · 003-2 ①②).
        ///
        /// 시안은 "개인방/공동방" 으로 나눠 적었지만 높이를 정하는 건 **카드 몇 장이 보이느냐** 뿐이라
        /// 방 종류가 아니라 개수로 받는다 — 개인방이 없는 계정이 생겨도 같은 규칙이 선다.
        ///
        /// - Parameter roomCount: 목록에 그릴 방 카드 수. 0(로드 전)은 1장과 같이 다룬다.
        static func half(roomCount: Int) -> CGFloat {
            let fullyShown = min(max(roomCount, 1), 2)
            let peeking = roomCount >= 3 ? thirdCardPeek : 0
            return chromeHeight + roomCardHeight * CGFloat(fullyShown) + peeking
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filter
            cardList
        }
    }

    // Figma `003-1-3` Frame 303(`2661:157261`): h70, px20. 타이틀(h32)과 아이콘 버튼(40×40)이
    // 둘 다 y=52 에서 끝나 **아래로 정렬**되고 그 아래 18 이 남는다(타이틀 y20 / 버튼 y12).
    // 그래서 가운데 정렬이 아니라 bottom 정렬 + padding 18 로 짠다.
    //
    // peek 에서 아래가 잘려도 콘텐츠는 y 12..52 라 타이틀·버튼이 온전히 보인다(``Metric/peek``).
    // full 상태에서 "×" 닫기 버튼 추가(gap 8, Figma `2661:157266`).
    private var header: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("방 리스트")
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .accessibilityIdentifier("RoomList.title")
            Spacer()
            HStack(spacing: 8) {
                MHIconButton(icon: .plus, accessibilityLabel: "방 추가", action: onCreateRoom)
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
        .padding(.bottom, Metric.headerBottomPadding)
        .frame(height: Metric.headerHeight, alignment: .bottom)
    }

    // Figma `003-1-3` Frame 305(`2661:157267`): h52, 좌우 padding 20, Category y=0 h32(size .medium)
    // — 칩이 블록 **위쪽**에 붙고 아래로 20 이 남는다.
    //
    // 개별 칩(전체/최근 저장 순/코멘트 순)은 `MHCategory`/`MHChip` 내부 Button 이라 화면단에서
    // identifier 를 부여할 수 없다(DS 컴포넌트가 접두사·식별자 훅을 노출하지 않음) — AXe 는 칩의
    // 기본 accessibility label(칩 텍스트, 예: "전체")로 탭한다. 선택 "상태"는 개별 칩에 trait/value 가
    // 없어 읽을 수 없으므로, 컨테이너(`RoomList.filter`)에 현재 선택된 칩 텍스트를
    // `accessibilityValue` 로 노출해 자동화가 선택 상태를 검증할 수 있게 한다.
    private var filter: some View {
        MHCategory(Self.filterItems, selection: $filterSelection, variant: .normal, size: .medium, horizontalPadding: true)
            .frame(height: Metric.filterHeight, alignment: .top)
            .accessibilityIdentifier("RoomList.filter")
            .accessibilityValue(Self.filterItems[filterSelection])
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
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectRoom?(room.id) }
                    .accessibilityAddTraits(.isButton)
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

    // 공동방이 없을 때 카드 바로 아래에 오는 빈 상태 — '공동방 생성' 고스트 Card
    // (003-1 ⑥ "개인방만 존재 시에만 노출된다", Figma `003-1-3` Frame 239 `2661:157272`).
    // 위아래 Spacer 로 수직 중앙을 잡되 minHeight 만 고정해 문구가 길어지면 늘어난다.
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // 유도 시트와 같은 블록이다(RoomCreationUI). CTA 만 자리마다 다르다.
            VStack(spacing: 24) {
                RoomCreationPromptMessage()

                MHButton("공동방 만들기", size: .medium, leadingIcon: .plus, action: onCreateRoom)
                    .accessibilityIdentifier("RoomList.createRoomButton")
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 423)   // Frame 239 높이. 내용 317 + 위아래 여백 53
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
    /// 도메인 `Room` → 카드 표시 모델.
    init(from room: Room) {
        self.init(
            id: room.id,
            title: room.name,
            memo: room.description,
            placeCount: room.pinCount,
            thumbnail: Self.thumbnail(for: room),
            members: AvatarPalette.images(of: Self.memberAvatarColors(of: room))
        )
    }

    /// 카드에 그릴 멤버 아바타 색 — 003-2 ⑤ "최대 5개 이상 표시하지 않는다 / 정렬(오른쪽 부터)
    /// 기준은 가장 최근에 위치를 저장한 사람 기준으로 우에서 좌로".
    ///
    /// 정렬 기준은 **서버가 이미 맞춰서 준다** — `GET /api/v1/rooms?showUsers=true` 스펙이
    /// "최근에 장소를 저장한 멤버가 먼저, 핀 없는 멤버는 가입순으로 뒤" 다. 여기서 할 일은 그 순서를
    /// 화면 방향에 맞추는 것뿐이다: ``MHAvatarGroup`` 은 배열 앞을 왼쪽에 놓으므로, 뒤집어야 최신이
    /// 오른쪽 끝에 선다.
    ///
    /// **자르기가 먼저, 뒤집기가 나중이다.** 순서를 바꾸면 최신 5명이 아니라 가장 오래된 5명이 남는다
    /// (``AvatarPalette/images(of:)`` 도 앞에서 자르므로 뒤집은 뒤 맡기면 그렇게 된다).
    static func memberAvatarColors(of room: Room) -> [AvatarColor?] {
        room.users.prefix(AvatarPalette.displayLimit).reversed().map(\.avatarColor)
    }

    private static func thumbnail(for room: Room) -> MHRoomThumbnailKind {
        // 003-2 ④ — 장소가 있으면 그 사진들이 콜라주로. 방 종류보다 우선한다(개인방도 사진이 쌓인다).
        if !room.placeThumbnails.isEmpty {
            return .fullRemote(room.placeThumbnails)
        }
        // 003-2 ③ — 장소 0개면 생성 시 고른 컬러칩+캐릭터 조합을 그대로 유지한다.
        switch room.type {
        case .personal:
            return .myRoom
        case .shared:
            // 서버가 주는 색 이름을 팔레트 12색에 매핑. 모르는 이름이면 my-room 썸네일로 폴백.
            return room.color.flatMap(RoomColorPalette.thumbnail(for:)).map { .color($0) } ?? .myRoom
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
