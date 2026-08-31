import Domain
import MVI

/// 홈 진입 화면 상태.
public struct HomeState: Equatable {
    public var rooms: [Room]
    public var isLoading: Bool
    public var errorMessage: String?
    /// 현재 조회 기준(필터 칩). 덱을 다 넘기면 이 방의 **미확인 정렬**로 자동 전환된다.
    public var selectedFilter: PinFilter
    /// **현재 방**의 기준별 덱(캐시). 칩을 오가도 재조회 없이 이어 본다 — 칩으로 건너뛴 덱도
    /// 방이 바뀌기 전에 마저 볼 수 있어야 하므로(SC-002) 보던 위치를 그대로 들고 있는다.
    /// 방이 바뀌면 비운다.
    public var decks: [PinFilter: [Pin]]
    /// 방 우선 순회의 커서 — `rooms` 배열 인덱스. 이 방의 세 정렬을 다 보면 다음 방으로 +1 된다.
    public var currentRoomIndex: Int
    /// 현재 방에서 **끝까지 본** 정렬. 다음에 어느 정렬로 넘어갈지(미확인 정렬) 판단에 쓴다.
    /// 방이 바뀌면 비운다 — 방마다 세 정렬을 새로 본다.
    public var viewedFilters: Set<PinFilter>
    /// 자동 전환 순서의 기준 — 사용자가 마지막으로 **직접 고른** 정렬. 기본은 꾹 Pick 이고,
    /// 방이 바뀌면 기본으로 되돌린다(정책: 방 진입 시 우선순위는 꾹 Pick → 최신순 → 가까운순).
    public var filterAnchor: PinFilter
    /// 다른 기준의 덱을 받아오는 중인지. 받는 동안에는 빈 상태·소진 화면을 띄우지 않는다(깜빡임 방지).
    public var isDeckLoading: Bool
    /// 현재 맨 앞 카드 인덱스
    public var currentCardIndex: Int
    /// 방 선택 바텀 시트 표시 여부 (뱃지·캐릭터 탭으로 열림).
    public var isRoomListPresented: Bool
    /// 방 변경 직후 뜨는 툴팁이 가리키는 방의 id (nil = 숨김). 3초 후 자동으로 nil 이 된다(FR-016).
    /// 표시 문구(방 이름)는 뷰가 이 id 로 rooms 에서 파생한다 — 이름이 같은 방도 안정적으로 식별하려 id 로 든다.
    public var changedRoomToastID: String?
    /// 홈 사용 가이드(좌우 스와이프 안내) 표시 여부. 최초 진입 1회만 뜬다(Figma 「홈 사용 가이드」).
    public var isGuidePresented: Bool
    /// 게시물 저장 시트 상태 (nil = 닫힘). 카드 더보기 메뉴 "다른 방 저장" 으로 열린다.
    public var savePost: SavePostState?
    /// 저장 완료 토스트(Figma 013-2)의 식별자 (nil = 숨김). 저장할 때마다 1씩 올라가
    /// 뷰의 자동 dismiss 타이머가 매번 새로 시작된다 — 연속 저장에서 앞 타이머가 뒤 토스트를 지우지 않게
    /// dismiss action 이 이 id 를 실어 보낸다([[changedRoomToastID]] 와 같은 방어).
    public var savedToastID: Int?
    /// 완료 토스트의 **진입 경로** (문구는 뷰가 이 값에서 파생한다 — [[changedRoomToastID]] 와 같은 방식).
    /// [[savedToastID]] 가 nil 인 동안에는 의미가 없다.
    ///
    /// 두 경로가 같은 토스트 자리를 쓰지만 문구는 스펙이 따로 정해 두었다 — 홈 카드 `다른 방 저장`은
    /// [SYS-002] 「게시물 저장」이라 `저장이 완료됐습니다.`(Figma 013-2), 장소 상세 [다른방에 공유]는
    /// [SYS-003] 이라 `공유가 완료되었습니다.`(place-detail 2.2.0 유저 플로우 6·TS-033)다.
    public var savedToastKind: SavedToastKind = .saved
    /// 가까운순 조회의 기준점(내 위치). 그 기준을 처음 고른 순간에 한 번 얻어 들고 있는다 —
    /// 서버가 `sort=nearby` 에 좌표를 요구하고, 매번 다시 측위하면 칩을 오갈 때마다 몇 초씩 걸린다.
    public var myCoordinate: Coordinate?
    /// 데이터가 있는 자리를 찾는 중인 임시 커서 (nil = 순회 중 아님).
    /// 찾는 동안 화면은 직전 자리 그대로다 — ``DeckProbe`` 참조.
    var probe: DeckProbe?

    public init(
        rooms: [Room] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        selectedFilter: PinFilter = .recommended,
        pins: [Pin] = [],
        isDeckLoading: Bool = false,
        currentCardIndex: Int = 0,
        currentRoomIndex: Int = 0,
        viewedFilters: Set<PinFilter> = [],
        filterAnchor: PinFilter = .recommended,
        isRoomListPresented: Bool = false,
        changedRoomToastID: String? = nil,
        isGuidePresented: Bool = false,
        savePost: SavePostState? = nil,
        savedToastID: Int? = nil,
        savedToastKind: SavedToastKind = .saved,
        myCoordinate: Coordinate? = nil,
        probe: DeckProbe? = nil
    ) {
        self.rooms = rooms
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedFilter = selectedFilter
        self.decks = pins.isEmpty ? [:] : [selectedFilter: pins]
        self.isDeckLoading = isDeckLoading
        self.currentCardIndex = currentCardIndex
        self.currentRoomIndex = currentRoomIndex
        self.viewedFilters = viewedFilters
        self.filterAnchor = filterAnchor
        self.isRoomListPresented = isRoomListPresented
        self.changedRoomToastID = changedRoomToastID
        self.isGuidePresented = isGuidePresented
        self.savePost = savePost
        self.savedToastID = savedToastID
        self.savedToastKind = savedToastKind
        self.myCoordinate = myCoordinate
        self.probe = probe
    }

    /// 현재 기준의 카드 덱. 쓰기는 현재 기준의 덱만 갈아끼운다(다른 기준 캐시는 그대로).
    public var pins: [Pin] {
        get { decks[selectedFilter] ?? [] }
        // 빈 덱은 키를 남기지 않는다 — "받았는데 0장"과 "아직 안 받음"을 같게 둬야 상태가 정규화되고,
        // 다시 그 기준으로 갈 때 재조회한다(빈 캐시로 굳지 않게).
        set { decks[selectedFilter] = newValue.isEmpty ? nil : newValue }
    }

    /// 홈 빈 상태(일러스트 + "공동방 만들기" CTA)를 보여줄지. 정책: 로딩이 끝났고, 현재 정렬 기준으로
    /// 표시할 카드가 0장이면(방·공동방 유무 무관) 빈 상태다 — "방이 0개일 때"가 아니라 "볼 장소가 0일 때".
    /// (PRD [SCR-003] Flow F / [SYS-009] Flow C). CTA 는 공동방 유무와 무관하게 항상 노출한다
    /// (팀 정책 결정 — 공동방 있으면 유도를 끄는 Flow D 와는 다름).
    public var showsEmptyState: Bool { hasNoCardToShow && !showsRoomIdentity }

    /// 지금 내놓을 카드가 없다 — 덱이 비었거나 끝까지 넘겼다.
    ///
    /// 자리를 찾는 중(``probe`` 가 있을 때)에는 아직 판정하지 않는다. "없다" 가 확정이 아니고,
    /// 그때 화면을 갈아끼우면 한 프레임 깜빡인다.
    var hasNoCardToShow: Bool {
        !isLoading && !isDeckLoading && probe == nil && (pins.isEmpty || isCurrentDeckExhausted)
    }

    /// 홈 상단 방 정체성(방 칩·마스코트)을 노출할지. **어느 기준으로든 받아 둔 장소가 있거나 공동방이 하나라도
    /// 있으면** 노출한다 → 오직 개인방만 있고 그마저 비었을 때만 로고(GGUK)·마스코트를 숨긴다.
    /// 현재 기준(`pins`)이 아니라 `decks` 전체를 보는 이유: 마스코트·뱃지는 방 변경 바텀시트의 유일한 진입점이라
    /// (PRD [SCR-003] Flow E), 지금 칩의 덱만 비었다고 숨기면 다른 칩엔 장소가 있는데도 방을 바꿀 길이 사라진다.
    /// (공동방이 있으면 방이 비어도 방 리스트로 전환할 수 있어야 하므로 칩·마스코트를 유지한다)
    /// 빈 상태 본문([[showsEmptyState]]) 노출과는 독립 — 방 칩·마스코트를 띄운 채 empty state 를 보일 수 있다.
    public var showsRoomIdentity: Bool {
        decks.values.contains { !$0.isEmpty } || rooms.contains { $0.type == .shared }
    }

    /// 현재 방 — 방 우선 순회의 커서가 가리키는 방(뱃지·마스코트·방 리스트 선택 표시의 기준).
    /// 카드에서 파생하지 않고 커서를 진실로 삼는다: 한 덱은 한 방의 것이고, 덱을 다 넘겨 인덱스가
    /// 덱 밖으로 나간 순간에도([[isCurrentDeckExhausted]]) 뱃지는 그 방에 머물러야 하기 때문.
    public var currentRoom: Room? {
        guard !rooms.isEmpty else { return nil }
        return rooms[min(max(0, currentRoomIndex), rooms.count - 1)]
    }

    /// 이 방에서 정렬을 노출할 순서 — 사용자가 고른 정렬([[filterAnchor]])이 먼저, 나머지는 기본 순서.
    /// 정책: 기본 진입 꾹 Pick → 최신순 → 가까운순 / 최신순 선택 최신순 → 꾹 Pick → 가까운순 /
    /// 가까운순 선택 가까운순 → 꾹 Pick → 최신순.
    public var filterOrder: [PinFilter] {
        [filterAnchor] + PinFilter.allCases.filter { $0 != filterAnchor }
    }

    /// 현재 정렬을 다 본 뒤 이어서 볼 정렬 — [[filterOrder]] 에서 아직 확인하지 않은 첫 정렬.
    /// nil 이면 이 방의 세 정렬을 모두 봤다는 뜻이라 다음 방으로 넘어간다.
    public var nextUnviewedFilter: PinFilter? {
        filterOrder.first { $0 != selectedFilter && !viewedFilters.contains($0) }
    }

    /// 이어서 볼 방이 남아 있는지 (방 우선 순회의 다음 커서).
    public var hasNextRoom: Bool { currentRoomIndex + 1 < rooms.count }

    /// 볼 카드가 없고, **쓸 방은 있는** 상태 (Figma 002-3 「모든 카드를 다 봤을 때」).
    ///
    /// 아직 아무것도 저장하지 않은 계정(공동방도 없고 어느 정렬에도 카드가 없음)은 여기가 아니라
    /// [[showsEmptyState]] 로 간다 — 그쪽은 `공동방 만들기` 로 다음 행동을 준다.
    public var hasViewedAllPlaces: Bool { hasNoCardToShow && showsRoomIdentity }

    /// 현재 정렬의 덱을 끝까지 넘겼는지(다음 갈 곳 유무와 무관). 갈 곳이 남아 있으면 소진 화면 대신
    /// 그쪽으로 자동 전환한다 — 그래서 화면 판정([[hasViewedAllPlaces]])과 분리해 둔다.
    var isCurrentDeckExhausted: Bool { !pins.isEmpty && currentCardIndex >= pins.count }

    /// 현재 정렬 덱에서 (현재 카드 포함) 아직 넘기지 않은 카드 수.
    /// 덱을 다 넘겨 인덱스가 덱 밖으로 나가면([[isCurrentDeckExhausted]]) 0 이다.
    public var remainingInCurrentDeck: Int { max(0, pins.count - currentCardIndex) }
}

/// 데이터가 있는 자리를 찾는 **임시 커서**. 화면에는 반영하지 않는다.
///
/// 빈 정렬·빈 방을 지나갈 때 방 뱃지와 정렬 칩이 자리마다 바뀌면, 사용자는 화면이 저 혼자
/// 움직인다고 읽는다 — 실기에서 이게 문제로 잡혔다. 그래서 순회하는 동안에는 커서만 옮기고
/// 화면은 **직전 자리 + 로딩** 그대로 두었다가, 카드가 있는 자리를 찾은 순간 한 번에 커밋한다.
///
/// 지나간 방의 「…방이에요」 툴팁도 뜨지 않는다 — 들르지 않은 방이기 때문이다.
public struct DeckProbe: Equatable, Sendable {
    var roomIndex: Int
    var filter: PinFilter
    /// 이 순회에서 확인을 끝낸 정렬(지금 커서의 방 기준).
    var viewedFilters: Set<PinFilter>
    /// 그 방의 정렬을 다 봤을 때 **다음 방으로 넘어가는가**.
    ///
    /// 스와이프로 소진해 온 길이면 넘어간다(마지막 방의 마지막 카드까지 이어 본다).
    /// 방을 여는 길(앱 실행·방 시트 선택)이면 넘어가지 않는다 — 사용자가 지목한 방을 두고
    /// 다른 방에 가 있으면 자기가 어디 있는지 알 수 없다.
    var crossesRooms: Bool
}

/// 완료 토스트를 띄운 경로. 문구가 경로마다 다르게 정해져 있어(각 스펙) 상태는 경로만 들고
/// 문구는 뷰가 고른다.
public enum SavedToastKind: Equatable, Sendable {
    /// 홈 카드 `다른 방 저장` — [SYS-002] 「게시물 저장」.
    case saved
    /// 장소 상세 [다른방에 공유] — [SYS-003] 「방 선택 시트」.
    case shared
}

/// `다른 방 저장` 으로 열리는 「게시물 저장 시트」([SYS-002], 002-5 ②)의 상태 (nil = 닫힘).
///
/// 시트가 홈 화면 안에서 열고 닫히므로 별도 Store 없이 홈 상태의 한 조각으로 든다 —
/// 저장 완료 토스트가 시트가 닫힌 **뒤** 홈 위에 뜨기 때문에 두 상태가 같은 reduce 안에 있어야 이어진다.
///
/// 이미 그 장소가 담긴 방은 체크된 채 **비활성**으로 뜬다(013-1-3). 그 목록은 시트를 열 때
/// ``FetchShareTargetsUseCase`` 로 받는다 — 한 장소가 여러 방에 담길 수 있어 카드가 든 `roomID`
/// 하나로는 부족하고, 핀 id 는 방마다 달라 **장소 id** 로만 물을 수 있다.
public struct SavePostState: Equatable {
    /// 저장하려는 장소(카드).
    public var pinID: PinID
    /// 이 장소가 이미 담긴 방 — 체크된 채 눌리지 않는다. 조회가 도착하기 전에는 비어 있다.
    public var alreadySavedRoomIDs: Set<String>
    /// 사용자가 이번에 새로 고른 방. 복수 선택이며, 빈 채로 열린다.
    public var selectedRoomIDs: Set<String>
    public var isSaving: Bool

    public init(
        pinID: PinID,
        alreadySavedRoomIDs: Set<String> = [],
        selectedRoomIDs: Set<String> = [],
        isSaving: Bool = false
    ) {
        self.pinID = pinID
        self.alreadySavedRoomIDs = alreadySavedRoomIDs
        self.selectedRoomIDs = selectedRoomIDs
        self.isSaving = isSaving
    }

    /// `저장하기` 활성 조건 — 이번에 **새로** 고른 방이 있어야 한다. 이미 담긴 방과 섞지 않는 이유는
    /// 섞으면 "이미 저장된 방만 있는" 상태에서 버튼이 켜지기 때문이다.
    public var canSubmit: Bool { !selectedRoomIDs.isEmpty && !isSaving }

    /// 체크로 보이는 방 — 이미 담긴 방도 체크 상태다(013-1-3).
    public var checkedRoomIDs: Set<String> { alreadySavedRoomIDs.union(selectedRoomIDs) }
}

public enum HomeAction: Equatable {
    case load
    /// 가까운순 덱을 여는 길에 얻은 내 위치. 다음 가까운순 조회가 다시 측위하지 않게 들고 있는다.
    case myCoordinateResolved(Coordinate)
    case loaded([Room])
    case loadFailed(DomainError)
    case selectFilter(PinFilter)
    /// 최초 진입 덱이 도착했다 — 이어 볼 방(마지막으로 본 방)의 꾹 Pick 덱. `roomID` 가 그 방이다.
    case initialDeckLoaded(pins: [Pin], roomID: String)
    /// 한 (방 × 정렬) 덱이 도착했다. `roomID`·`filter` 는 이 응답이 **어느 자리의 것인지** —
    /// 칩·방을 연속으로 옮겨 응답이 엇갈려 도착해도 지나간 자리의 덱이 화면을 끌고 가지 않게 한다.
    /// 덱은 언제나 **첫 카드**부터 시작한다(되돌리기가 덱 경계를 넘지 않으므로 뒤에서 들어올 일이 없다).
    case deckLoaded(pins: [Pin], roomID: String, filter: PinFilter)
    /// 순회 커서가 확인한 자리의 결과. 비면 다음 자리로, 카드가 있으면 그 자리를 화면에 커밋한다.
    /// `deckLoaded` 와 나눠 둔 이유는 **화면에 반영할 시점이 다르기** 때문이다 —
    /// 이쪽은 찾을 때까지 화면을 건드리지 않는다(``DeckProbe``).
    case probeLoaded(pins: [Pin], roomIndex: Int, filter: PinFilter)
    /// 덱 조회 실패 — 가려던 자리를 버리고 조회 직전 자리로 되돌린다.
    case deckLoadFailed(roomID: String, filter: PinFilter, revertTo: DeckPosition)
    case tapCreateRoom
    case swipeForward
    case swipeBackward
    case tapCard(PinID)
    /// 카드 탭이 실제로 상세를 여는 순간. `tapCard` 와 나눠 둔 이유는 그 자리에서 「경과일 초기화 확인」도
    /// 함께 보내야 하는데, 한 Effect 는 화면 전환과 네트워크 중 하나만 낼 수 있어서다 —
    /// 전환을 먼저 내보내고 기록은 그 뒤에 붙인다(기록 응답을 기다리면 탭이 네트워크만큼 늦어진다).
    case openPlaceDetail(Pin)
    /// 홈 사용 가이드를 아직 안 봤는지 묻는다(최초 진입 1회 정책). `load` 와 나눠 두는 이유는
    /// 가이드가 그리는 카드 덱이 모형이라(``HomeGuideMockDeck``) 방·덱 조회 결과를 기다릴
    /// 이유가 없고, 조회가 늦거나 실패해도 안내는 떠야 하기 때문이다.
    case checkGuide
    /// 홈 사용 가이드를 띄운다 — 아직 안 보여준 최초 진입일 때만 도착하는 응답 action.
    case showGuide
    /// 가이드 X 버튼 탭 → 닫기
    case dismissGuide
    /// 방 뱃지·캐릭터 탭 → 방 선택 바텀 시트 토글(열려 있으면 닫는다)
    case tapRoomBadge
    /// 방 선택 바텀 시트 닫기 (스와이프 dismiss 포함)
    case dismissRoomList
    /// 바텀 시트에서 방 선택 → 해당 방으로 즉시 전환
    case selectRoom(String)
    /// 방 변경 툴팁 숨기기 (노출 3초 후 자동 발생). 연관값은 이 타이머가 세운 방의 id —
    /// 3초가 도는 사이 다른 방으로 바꾸면 이전 타이머가 새 방 툴팁을 지우지 않도록 방어한다.
    case dismissRoomToast(String)
    /// 카드 더보기 메뉴 "다른 방 저장" 탭 → 게시물 저장 시트 열기
    case tapSaveToOtherRoom(PinID)
    /// 게시물 저장 시트 닫기 (스와이프 dismiss 포함)
    case dismissSavePost
    /// 게시물 저장 시트가 쓸 "이 장소가 이미 담긴 방" 목록이 도착했다.
    /// `pinID` 는 이 응답이 **어느 시트의 것인지** — 시트를 닫고 다른 카드로 다시 열면 지나간
    /// 응답이 새 시트의 비활성 표시를 뒤덮지 않게 한다.
    case savePostTargetsLoaded(pinID: PinID, alreadySavedRoomIDs: Set<String>)
    /// 게시물 저장 시트에서 방 체크를 켜고 끈다(복수 선택).
    case toggleSavePostRoom(String)
    /// `저장하기` 탭 → 고른 방 **전부**에 저장한다(FR-025).
    case tapSavePost
    /// 저장 작업이 끝남 → 시트를 닫고 완료 토스트를 띄운다.
    case savePostFinished
    /// 저장 실패 — 시트를 저장 전 상태로 되돌린다.
    case savePostFailed
    /// 저장 완료 토스트 숨기기 (노출 2초 후 자동 발생). 연관값은 이 타이머가 띄운 토스트의 id.
    case dismissSavedToast(Int)
    /// 「다른 방에 공유」 시트(011-1)에서 저장이 끝났다. 시트를 닫는 일은 Coordinator 가 하고
    /// (시트 표시는 Coordinator 가 쥔다), 여기서는 완료 토스트만 세운다 — 저장 경로가 달라도
    /// 사용자에게는 같은 "저장 완료" 라 013-2 토스트를 그대로 쓴다.
    case sharedToOtherRooms
}

public enum HomeNav: Equatable, Sendable {
    case goToCreateRoom
    /// 카드 탭 → 그 장소의 상세 화면 (Figma 002-1-1).
    ///
    /// 식별자가 아니라 핀을 통째로 싣는다. 상세가 그리는 사진·저장자·라벨이 전부 이 값 안에 있어,
    /// id 만 넘기면 받아 둔 덱을 두고 같은 장소를 다시 조회하게 된다.
    case openPlaceDetail(Pin)
}

public typealias HomeStore = Store<HomeState, HomeAction, HomeNav>

// MARK: - 방 이름 표기

extension Room {
    /// 홈 표기용 이름 — 공동방은 "…방", 개인방은 이름과 무관하게 항상 "내 장소". (Figma: 방 리스트·뱃지)
    var homeDisplayName: String { type == .shared ? "\(name)방" : Self.personalDisplayName }

    /// 방 변경 툴팁 문구 — 공동방 "…방이에요.", 개인방 "내 장소예요."
    /// (개인방은 받침이 없어 조사가 "이에요"가 아니라 "예요"라 뷰에서 붙이지 않고 여기서 완성한다)
    var homeToastText: String { "\(homeDisplayName)\(type == .shared ? "이에요." : "예요.")" }
}

/// 덱 조회가 실패했을 때 되돌아갈 자리 — 조회를 시작하기 **직전**의 순회 상태.
///
/// 커서(방·정렬·카드)만으로는 부족하다: 방을 옮길 때는 덱 캐시·확인 기록·정렬 우선순위·전환 안내까지
/// 새 방 기준으로 갈아엎기 때문에, 그것들을 함께 들고 있지 않으면 조회가 실패했을 때 옛 방의 카드가
/// 사라진 빈 화면(공동방 만들기 CTA)이 남는다.
public struct DeckPosition: Equatable, Sendable {
    public var roomIndex: Int
    public var filter: PinFilter
    public var cardIndex: Int
    public var decks: [PinFilter: [Pin]]
    public var viewedFilters: Set<PinFilter>
    public var filterAnchor: PinFilter
    public var changedRoomToastID: String?
    var probe: DeckProbe?

    public init(
        roomIndex: Int,
        filter: PinFilter,
        cardIndex: Int,
        decks: [PinFilter: [Pin]] = [:],
        viewedFilters: Set<PinFilter> = [],
        filterAnchor: PinFilter = .recommended,
        changedRoomToastID: String? = nil,
        probe: DeckProbe? = nil
    ) {
        self.roomIndex = roomIndex
        self.filter = filter
        self.cardIndex = cardIndex
        self.decks = decks
        self.viewedFilters = viewedFilters
        self.filterAnchor = filterAnchor
        self.changedRoomToastID = changedRoomToastID
        self.probe = probe
    }

    /// 지금 자리를 그대로 담는다 — 조회를 시작하며 상태를 건드리기 **전에** 캡처해야 한다.
    public init(_ state: HomeState) {
        self.init(
            roomIndex: state.currentRoomIndex,
            filter: state.selectedFilter,
            cardIndex: state.currentCardIndex,
            decks: state.decks,
            viewedFilters: state.viewedFilters,
            filterAnchor: state.filterAnchor,
            changedRoomToastID: state.changedRoomToastID,
            probe: state.probe
        )
    }
}

/// 한 정렬 덱의 최대 카드 수 — 정책: 각 정렬은 최대 10장, 모자라면 보유한 만큼만.
private let deckPageSize = 10

/// 지금 방의 `filter` 덱으로 옮긴다. 받아 둔 덱이 있으면 재조회 없이 즉시 전환하고,
/// 없으면 그 방의 첫 페이지를 받아 `deckLoaded` 로 되돌린다. 실패도 `deckLoadFailed` 로 되돌려
/// 조회 직전 자리로 복구한다 — 성공했을 때만 되돌리면 isDeckLoading 이 꺼지지 않아 스피너에 멈춘다.
private func showDeck(
    filter: PinFilter,
    revertingTo revert: DeckPosition,
    persistingRoom persist: Bool = false,
    state: inout HomeState,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase,
    lastViewedRoom: LastViewedRoomUseCase
) -> Effect<HomeAction, HomeNav> {
    // revert 는 여기서 만들지 않고 호출부가 넘긴다 — 방 전환은 showDeck 을 부르기 **전에** 커서·캐시를
    // 새 방 기준으로 바꿔 두므로, 여기서 캡처하면 "옛 자리"가 아니라 이미 바뀐 자리를 담게 된다.
    state.selectedFilter = filter
    if let cached = state.decks[filter], !cached.isEmpty {
        state.currentCardIndex = 0
        return .none
    }
    guard let room = state.currentRoom else { return .none }
    state.isDeckLoading = true   // 받는 동안 빈 상태·소진 화면이 끼어들지 않게 한다
    let known = state.myCoordinate
    return .run { send in
        do {
            // 정책 3: 재실행 시 마지막으로 보던 방부터 이어 본다 — 방을 옮길 때 함께 기록한다.
            if persist { await lastViewedRoom.save(roomID: room.id) }
            // 가까운순은 좌표 없이 요청하면 서버가 거절한다. 위치가 필요해진 순간(이 기준을 고른
            // 순간)에만 묻는다 — 홈 진입에서 미리 물으면 요청 맥락이 사라진다.
            var origin = known
            if filter == .nearby, origin == nil {
                guard case .coordinate(let resolved) = await currentLocation.execute() else {
                    // 정책(EC-009): 권한을 거부하면 가까운순을 **소진된 것으로 처리**하고 같은 방의 남은
                    // 덱으로 넘어간다 — 조회 실패로 되돌리면 사용자가 거부한 그 자리에 갇힌다.
                    // 빈 덱은 `deckLoaded` 가 이미 "확인한 것으로 치고 다음 자리로" 보내 준다.
                    send(.deckLoaded(pins: [], roomID: room.id, filter: filter))
                    return
                }
                origin = resolved
                send(.myCoordinateResolved(resolved))   // 한 번 얻으면 이후 가까운순은 다시 묻지 않는다
            }
            let pins = try await fetchHomeCards.execute(room: room, filter: filter, origin: origin)
            send(.deckLoaded(pins: Array(pins.prefix(deckPageSize)), roomID: room.id, filter: filter))
        } catch is CancellationError {
            return   // 취소는 결과가 없는 것이지 실패가 아니다
        } catch {
            send(.deckLoadFailed(roomID: room.id, filter: filter, revertTo: revert))
        }
    }
}

/// 방을 옮긴다 — 정렬 상태(확인 기록·우선순위·덱 캐시)를 새 방 기준으로 초기화하고 첫 정렬 덱을 연다.
/// 커서 자리에서 **다음으로 확인할 자리**를 고른다 (nil = 더 갈 곳이 없다).
///
/// 같은 방의 남은 정렬을 먼저 훑고, 그 방을 다 봤으면 다음 방의 꾹 Pick 으로 넘어간다
/// (``DeckProbe/crossesRooms`` 일 때만). **새 방은 언제나 꾹 Pick 부터** 시작한다.
private func nextProbeTarget(after probe: DeckProbe, in state: HomeState) -> DeckProbe? {
    // 지금 보고 있는 방에서는 사용자가 고른 정렬이 앞에 오고(filterOrder), 넘어간 방은 기본 순서다.
    let order = probe.roomIndex == state.currentRoomIndex ? state.filterOrder : PinFilter.allCases
    // 가까운순은 좌표가 있어야 서버가 받는다. 순회 중 측위가 한 번 걸릴 수 있지만 후보에서 빼지는
    // 않는다 — 그 방의 데이터가 가까운순에만 있을 수 있고, 권한 거부는 EC-009 가 "후보 0건" 으로
    // 규정해 두었다. 측위는 첫 한 번뿐이고 그 뒤로는 [[HomeState.myCoordinate]] 를 재사용한다.
    if let next = order.first(where: { !probe.viewedFilters.contains($0) }) {
        var target = probe
        target.filter = next
        return target
    }
    guard probe.crossesRooms else { return nil }
    // **저장 장소가 0개인 방은 조회 없이 건너뛴다**(FR-013). 방 목록이 `pinCount` 를 이미 실어 주므로
    // 빈 방마다 왕복하며 서 있을 이유가 없다 — 순회가 느리게 체감되던 가장 큰 원인이었다.
    var nextRoom = probe.roomIndex + 1
    while state.rooms.indices.contains(nextRoom), state.rooms[nextRoom].pinCount == 0 {
        nextRoom += 1
    }
    guard state.rooms.indices.contains(nextRoom) else { return nil }
    return DeckProbe(roomIndex: nextRoom, filter: .recommended, viewedFilters: [], crossesRooms: true)
}

/// 커서 자리의 덱을 받아 본다. **화면 상태는 건드리지 않는다** — 커서와 로딩만 세운다.
private func fetchProbe(
    _ probe: DeckProbe,
    revertingTo revert: DeckPosition,
    state: inout HomeState,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase
) -> Effect<HomeAction, HomeNav> {
    guard state.rooms.indices.contains(probe.roomIndex) else { return finishProbe(&state) }
    let room = state.rooms[probe.roomIndex]
    state.probe = probe
    state.isDeckLoading = true   // 받는 동안 빈 상태·소진 화면이 끼어들지 않게 한다
    let known = state.myCoordinate
    return .run { send in
        do {
            var origin = known
            if probe.filter == .nearby, origin == nil {
                guard case .coordinate(let resolved) = await currentLocation.execute() else {
                    // 정책(EC-009): 권한 거부는 실패가 아니라 "그 정렬엔 볼 게 없다" 로 받는다.
                    send(.probeLoaded(pins: [], roomIndex: probe.roomIndex, filter: probe.filter))
                    return
                }
                origin = resolved
                send(.myCoordinateResolved(resolved))
            }
            let pins = try await fetchHomeCards.execute(room: room, filter: probe.filter, origin: origin)
            send(.probeLoaded(pins: Array(pins.prefix(deckPageSize)), roomIndex: probe.roomIndex, filter: probe.filter))
        } catch is CancellationError {
            return   // 취소는 결과가 없는 것이지 실패가 아니다
        } catch {
            // **빈 덱과 조회 실패는 다르다.** 빈 자리는 지나가지만(스루), 실패는 순회 직전 자리로
            // 되돌린다 — 실패를 빈 것으로 뭉개면 "다 봤다" 로 읽혀 보던 덱까지 사라진다.
            send(.deckLoadFailed(roomID: room.id, filter: probe.filter, revertTo: revert))
        }
    }
}

/// 더 갈 곳이 없다 — 커서를 걷고 화면을 확정한다(완료 또는 빈 상태).
private func finishProbe(_ state: inout HomeState) -> Effect<HomeAction, HomeNav> {
    state.probe = nil
    state.isDeckLoading = false
    return .none
}

/// 순수 reduce. UseCase(fetchRooms·fetchHomeCards·lastViewedRoom)는 Effect.run 안에서만 사용한다.
public func homeReducer(
    fetchRooms: FetchRoomsUseCase,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase,
    lastViewedRoom: LastViewedRoomUseCase,
    homeGuide: HomeGuideUseCase,
    savePin: SavePinToRoomsUseCase,
    recordPinAccess: RecordPinAccessUseCase,
    fetchShareTargets: FetchShareTargetsUseCase
) -> (inout HomeState, HomeAction) -> Effect<HomeAction, HomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
                do {
                    let rooms = try await fetchRooms.execute()
                    send(.loaded(rooms))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .myCoordinateResolved(let coordinate):
            state.myCoordinate = coordinate
            return .none

        case .loaded(let rooms):
            // 홈은 개인방(personal, "내 장소")을 먼저, 그다음 공동방(shared)을 보여준다 — 데이터 순서와
            // 무관하게 항상 이 순서. 공동방 내부 순서는 서버가 준 순서를 그대로 유지(클라 정렬 없음).
            // 이 순서가 곧 **방 우선 순회의 순서**이기도 하다(뱃지·카드덱·방리스트가 모두 이 order 를 따른다).
            let ordered = rooms.filter { $0.type == .personal } + rooms.filter { $0.type == .shared }
            state.rooms = ordered
            // isLoading 은 여기서 끄지 않는다 — 첫 덱까지 도착해야 표시할 카드 유무가 정해지므로
            // initialDeckLoaded 에서 끈다. (여기서 끄면 카드 도착 전 빈 상태+CTA 가 한 프레임 깜빡인다)
            return .run { send in
                do {
                    // 정책 3: 재실행 시 마지막으로 보던 방부터 이어 본다. 그 방이 사라졌으면 첫 방.
                    let startRoomID = await lastViewedRoom.load()
                    let room = ordered.first { $0.id == startRoomID } ?? ordered.first
                    guard let room else {
                        send(.initialDeckLoaded(pins: [], roomID: ""))
                        return
                    }
                    // 진입 정렬은 항상 꾹 Pick (정책: 홈 최초 진입 시 기본 정렬).
                    let pins = try await fetchHomeCards.execute(room: room, filter: .recommended, origin: nil)
                    send(.initialDeckLoaded(pins: Array(pins.prefix(deckPageSize)), roomID: room.id))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loadFailed(let error):
            state.isLoading = false
            // TODO: 에러 UI 미구현 — errorMessage 는 로컬 DomainError 케이스명("unknown" 등)이라 사용자 노출 불가이고,
            //   현재 화면(로딩/빈상태/덱 분기)은 이 값을 읽지 않아 실패 시 빈 화면이 된다. 에러 표시 정책(재시도 등)
            //   확정 시 사용자향 메시지로 교체하고 contentBody 에 실패 분기를 추가한다.
            state.errorMessage = "\(error)"
            return .none

        case .selectFilter(let filter):
            guard filter != state.selectedFilter else { return .none }
            // 정책: 직접 고른 정렬이 이후 자동 전환 순서의 기준이 된다(고른 것 먼저, 나머지는 기본 순서).
            let revert = DeckPosition(state)
            state.filterAnchor = filter
            state.viewedFilters.remove(filter)   // 다시 고른 정렬은 처음부터 다시 본다
            // 직접 누른 칩이다 — 그 정렬이 비어도 다른 칩으로 끌고 가지 않는다.
            state.probe = nil
            return showDeck(
                filter: filter, revertingTo: revert,
                state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom
            )

        case .deckLoaded(let pins, let roomID, let filter):
            // 지나간 방의 응답은 캐시에도 담지 않는다 — 덱 캐시는 지금 방의 것이다.
            guard roomID == state.currentRoom?.id else { return .none }
            state.decks[filter] = pins.isEmpty ? nil : pins
            // 화면을 움직이는 건 지금 보고 있는 정렬의 응답일 때만. 아니면 남의 덱이 잠깐 앉았다 사라진다.
            guard filter == state.selectedFilter else { return .none }
            state.isDeckLoading = false
            state.currentCardIndex = 0
            // 이 경로는 **정렬 칩을 직접 누른** 조회다 — 비어도 다른 칩으로 끌고 가지 않는다.
            // 자동 순회는 `probeLoaded` 가 맡는다.
            return .none

        case .probeLoaded(let pins, let roomIndex, let filter):
            // 지나간 순회의 응답은 버린다 — 커서가 이미 다른 자리로 갔거나 순회가 끝났다.
            guard let probe = state.probe, probe.roomIndex == roomIndex, probe.filter == filter else { return .none }
            guard !pins.isEmpty else {
                var next = probe
                next.viewedFilters.insert(filter)
                guard let target = nextProbeTarget(after: next, in: state) else { return finishProbe(&state) }
                // 순회는 화면을 건드리지 않으므로 지금 자리가 곧 되돌아갈 자리다.
                return fetchProbe(target, revertingTo: DeckPosition(state), state: &state,
                                  fetchHomeCards: fetchHomeCards, currentLocation: currentLocation)
            }
            // 찾았다 — 지나온 자리는 건너뛰고 여기 한 번에 앉힌다.
            if roomIndex != state.currentRoomIndex {
                state.currentRoomIndex = roomIndex
                state.decks = [:]
                state.filterAnchor = .recommended
                state.changedRoomToastID = state.rooms[roomIndex].id   // 실제로 도착한 방만 안내한다
            }
            state.selectedFilter = filter
            state.decks[filter] = pins
            state.currentCardIndex = 0
            state.viewedFilters = probe.viewedFilters
            state.isDeckLoading = false
            state.probe = nil
            let landedRoomID = state.rooms[roomIndex].id
            return .run { _ in await lastViewedRoom.save(roomID: landedRoomID) }

        case .deckLoadFailed(let roomID, let filter, let revert):
            // 이미 다른 자리로 옮겨 갔으면 지나간 조회의 실패다 — 되돌리면 지금 화면을 엉뚱하게 끌고 간다.
            // 순회 중이면 화면이 아직 안 움직였으므로 **커서**와 대조한다.
            let matchesProbe = state.probe.map {
                state.rooms.indices.contains($0.roomIndex)
                    && state.rooms[$0.roomIndex].id == roomID && $0.filter == filter
            } ?? false
            guard matchesProbe || (roomID == state.currentRoom?.id && filter == state.selectedFilter) else { return .none }
            // 실패하면 가려던 자리를 버리고 조회 직전 자리로 되돌려 기존 덱을 계속 보여준다.
            // 자리를 새것으로 둔 채 로딩만 끄면 그 덱이 비어 빈 상태("공동방 만들기")가 뜬다 —
            // 조회가 실패한 건데 장소가 없다고 말하게 된다.
            state.isDeckLoading = false
            state.currentRoomIndex = revert.roomIndex
            state.selectedFilter = revert.filter
            // 방 전환 실패는 커서만 되돌려선 안 된다 — 옛 방의 덱 캐시·확인 기록·우선순위까지 함께
            // 갈아엎고 출발했기 때문에, 그대로 두면 카드가 사라진 빈 화면이 남는다.
            state.decks = revert.decks
            state.viewedFilters = revert.viewedFilters
            state.filterAnchor = revert.filterAnchor
            state.changedRoomToastID = revert.changedRoomToastID   // 옮긴 적 없으니 전환 안내도 거둔다
            state.probe = revert.probe
            // 소진 자동 전환 경로에선 인덱스가 이미 덱 밖(pins.count)으로 밀려 있어, 그대로 되돌리면
            // 카드 없는 덱 분기에 들어간다. 복구한 덱의 마지막 카드로 클램프해 거기서 다시 넘기면 재시도된다.
            state.currentCardIndex = min(revert.cardIndex, max(0, state.pins.count - 1))
            return .none

        case .tapCreateRoom:
            state.isRoomListPresented = false
            return .navigate(.goToCreateRoom)

        case .initialDeckLoaded(let pins, let roomID):
            state.currentRoomIndex = state.rooms.firstIndex { $0.id == roomID } ?? 0
            state.selectedFilter = .recommended
            state.filterAnchor = .recommended
            state.viewedFilters = []
            state.decks = [:]
            state.pins = pins
            state.currentCardIndex = 0
            state.isLoading = false   // 첫 덱까지 도착 → 이제 카드 유무가 확정돼 로딩 종료
            // 진입 정렬(꾹 Pick)이 비면 그 방 안에서 데이터가 있는 정렬을 찾는다 — 방은 넘기지 않는다.
            // 앱을 켠 직후 사용자가 고르지도 않은 방에 가 있으면 어디로 왔는지 알 수 없다.
            guard pins.isEmpty else { return .none }
            let revert = DeckPosition(state)
            let start = DeckProbe(
                roomIndex: state.currentRoomIndex, filter: .recommended,
                viewedFilters: [.recommended], crossesRooms: false
            )
            guard let target = nextProbeTarget(after: start, in: state) else { return .none }
            return fetchProbe(target, revertingTo: revert, state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation)

        case .swipeForward:
            // 마지막 카드에서 한 번 더 넘기면 인덱스가 덱 밖(pins.count)으로 나간다.
            if state.currentCardIndex < state.pins.count {
                state.currentCardIndex += 1
            }
            // 다 넘겼으면 남은 정렬 → 다음 방으로 이어 본다. **마지막 방의 마지막 카드**까지
            // 가서야 완료 화면([[HomeState.hasViewedAllPlaces]])에 선다.
            // 지나가는 자리는 화면에 비치지 않는다(``DeckProbe``).
            guard state.isCurrentDeckExhausted else { return .none }
            let revert = DeckPosition(state)
            var start = DeckProbe(
                roomIndex: state.currentRoomIndex, filter: state.selectedFilter,
                viewedFilters: state.viewedFilters, crossesRooms: true
            )
            start.viewedFilters.insert(state.selectedFilter)
            state.viewedFilters = start.viewedFilters
            guard let target = nextProbeTarget(after: start, in: state) else { return .none }
            return fetchProbe(target, revertingTo: revert, state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation)

        case .swipeBackward:
            // 되돌리기는 **현재 덱 안에서 넘긴 만큼 역순으로 이어진다**(FR-002). 덱이 바뀌면
            // 되돌리기 이력이 초기화되므로, 첫 카드에서 더 뒤로 가면 이전 덱으로 넘어가지 않고
            // 아무 일도 일어나지 않는다(EC-001·EC-003).
            //
            // 스펙 3.0.0 은 이걸 1단계로 묶어 뒀지만 4.0.0 이 뒤집었다 — 두 번째 되돌리기가
            // 아무 반응이 없어 고장으로 읽혔기 때문이다(TS-002a).
            guard state.currentCardIndex > 0 else { return .none }
            state.currentCardIndex -= 1
            return .none

        case .tapCard(let pinID):
            // 카드가 넘긴 건 id 뿐이라 지금 덱에서 핀을 되찾는다. 못 찾으면 아무 데도 가지 않는다 —
            // 덱이 갈리는 순간(방·기준 전환)에 들어온 탭이라 열어야 할 장소가 이미 없다.
            guard let pin = state.pins.first(where: { $0.id == pinID }) else { return .none }
            // 정책(FR-007·FR-023): 카드 탭은 상세로 이동하면서 「경과일 초기화 확인」①을 서버에 보낸다.
            // 덱의 진행 상태(잔여 카드·되돌리기 이력)는 그대로다 — 「카드 열람 확인」②은 넘길 때만 생긴다.
            return .run { send in
                send(.openPlaceDetail(pin))
                // 집계용 로그라 실패해도 사용자에게 알릴 것이 없고, 다시 열면 또 기록된다(append-only).
                try? await recordPinAccess.execute(pinID: pinID)
            }

        case .openPlaceDetail(let pin):
            return .navigate(.openPlaceDetail(pin))

        case .checkGuide:
            // 정책: 홈 사용 가이드는 최초 진입 1회. 카드 유무는 보지 않는다 — 가이드가 가리키는 덱은
            // 모형이라(``HomeGuideMockDeck``) 저장한 장소가 하나도 없는 계정에서도 안내가 성립한다.
            return .run { send in
                if await homeGuide.hasSeen() == false { send(.showGuide) }
            }

        case .showGuide:
            state.isGuidePresented = true
            // "단 1회"를 보장하려고 닫을 때가 아니라 띄우는 시점에 기록한다 —
            // 탭 전환으로 화면이 다시 만들어져도(store 재생성 → load 재실행) 두 번 뜨지 않는다.
            return .run { _ in await homeGuide.markSeen() }

        case .dismissGuide:
            state.isGuidePresented = false
            return .none

        case .tapRoomBadge:
            // 열려 있으면 닫는다. 실질적으로 마스코트 재탭 경로다 —
            // 뱃지는 딤에 가려 hit-test 가 막히고, 마스코트만 딤 위에 그려져 시트 중에도 탭된다.
            state.isRoomListPresented.toggle()
            return .none

        case .dismissRoomList:
            state.isRoomListPresented = false
            return .none

        case .selectRoom(let roomID):
            // 정책: 방 클릭 시 해당 방으로 바로 적용 + 시트 닫기 + 변경 툴팁.
            // 툴팁의 3초 표시 시간은 뷰(페이드 애니메이션과 함께)가 관리하고, 여기서는 상태만 세운다.
            state.isRoomListPresented = false
            guard let index = state.rooms.firstIndex(where: { $0.id == roomID }) else { return .none }
            // 정책(EC-014): 지금 보고 있는 방을 다시 고르면 시트만 닫고 덱을 다시 구성하지 않는다 —
            // 재구성하면 넘겨 둔 진행 상태가 통째로 날아간다.
            guard index != state.currentRoomIndex else { return .none }
            let revert = DeckPosition(state)   // 조회가 실패하면 옛 방으로 되돌린다
            // 방을 바꾼 것은 **사용자의 조작**이라 즉시 화면에 반영한다(뱃지·툴팁).
            // 그 방 안에서 어느 정렬을 열지는 커서가 찾아 한 번에 커밋한다 — 칩이 훑는 과정은 보이지 않는다.
            state.currentRoomIndex = index
            state.viewedFilters = []
            state.filterAnchor = .recommended
            state.selectedFilter = .recommended
            state.decks = [:]            // 덱 캐시는 방에 딸린 것이다
            state.currentCardIndex = 0
            state.changedRoomToastID = state.rooms[index].id
            let target = DeckProbe(
                roomIndex: index, filter: .recommended, viewedFilters: [], crossesRooms: false
            )
            // 정책 3의 "마지막으로 보던 방" 기록은 **착지할 때** 남긴다(`probeLoaded`) —
            // 카드를 못 찾고 지나갈 자리를 미리 적으면 다음 실행이 빈 방에서 시작한다.
            return fetchProbe(target, revertingTo: revert, state: &state,
                              fetchHomeCards: fetchHomeCards, currentLocation: currentLocation)

        case .dismissRoomToast(let roomID):
            // 이 타이머가 세운 그 방 툴팁일 때만(id 일치) 숨긴다. 3초가 도는 사이 방을 바꾸면
            // 이전 타이머의 dismiss 가 뒤늦게 도착해 새 방 툴팁을 지우는 걸 막는다.
            // id 로 비교하므로 이름이 같은 방들끼리도 정확히 구분된다.
            if state.changedRoomToastID == roomID {
                state.changedRoomToastID = nil
            }
            return .none

        case .tapSaveToOtherRoom(let pinID):
            // 정책(FR-005): 메뉴를 닫고 「게시물 저장 시트」를 연다. 덱의 진행 상태는 건드리지 않는다(TS-011).
            guard let pin = state.pins.first(where: { $0.id == pinID }) else { return .none }
            state.savePost = SavePostState(pinID: pinID)
            let placeID = pin.place.id
            // 방 목록은 이미 들고 있어 시트가 즉시 뜬다 — 이 조회는 그 위에 "이미 담긴 방" 표시만 얹는다.
            // 실패·취소는 삼킨다: 표시가 없을 뿐 저장은 되고, 그 상태로 이미 담긴 방을 고르면
            // 서버가 409 로 거절해 `savePostFailed` 로 돌아온다.
            return .run { send in
                guard let targets = try? await fetchShareTargets.execute(placeID: placeID) else { return }
                send(.savePostTargetsLoaded(pinID: pinID, alreadySavedRoomIDs: targets.alreadySavedRoomIDs))
            }

        case .savePostTargetsLoaded(let pinID, let alreadySaved):
            // 지나간 시트의 응답은 버린다 — 닫고 다른 카드로 다시 열었을 수 있다.
            guard var sheet = state.savePost, sheet.pinID == pinID else { return .none }
            sheet.alreadySavedRoomIDs = alreadySaved
            // 조회가 오기 전에 골라 둔 방이 "이미 담긴 방"으로 밝혀지면 선택에서 뺀다 —
            // 남겨 두면 비활성 칸이 저장 대상에 들어가 409 를 부른다.
            sheet.selectedRoomIDs.subtract(alreadySaved)
            state.savePost = sheet
            return .none

        case .dismissSavePost:
            // 저장 중 스와이프로 닫아도 막지 않는다 — 시스템 시트는 이미 닫힌 뒤라 상태만 되살리면
            // 시트가 도로 튀어 올라온다. 진행 중인 저장은 그대로 끝나 완료 토스트로 이어진다.
            state.savePost = nil
            return .none

        case .toggleSavePostRoom(let roomID):
            // 저장이 시작된 뒤 선택이 바뀌면 화면과 실제 저장 대상이 어긋난다.
            guard var sheet = state.savePost, !sheet.isSaving else { return .none }
            // 이미 담긴 방은 끌 수 없다 — 뷰가 체크박스를 비활성으로 그리지만, 뷰를 고치면 뚫린다.
            guard !sheet.alreadySavedRoomIDs.contains(roomID) else { return .none }
            if sheet.selectedRoomIDs.contains(roomID) {
                sheet.selectedRoomIDs.remove(roomID)
            } else {
                sheet.selectedRoomIDs.insert(roomID)
            }
            state.savePost = sheet
            return .none

        case .tapSavePost:
            // 뷰의 비활성 처리는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다(EC-018).
            guard var sheet = state.savePost, sheet.canSubmit else { return .none }
            sheet.isSaving = true
            state.savePost = sheet
            let pinID = sheet.pinID
            let roomIDs = sheet.selectedRoomIDs
            return .run { send in
                do {
                    // 이미 담긴 방은 고를 수 없으므로 여기 섞이지 않는다 — 새로 고른 방만 나간다(FR-025).
                    try await savePin.execute(pinID: pinID, roomIDs: roomIDs)
                    send(.savePostFinished)
                } catch {
                    send(.savePostFailed)
                }
            }

        case .savePostFinished:
            // 시트를 먼저 닫고 그 자리에 토스트만 남긴다(Figma 013-2).
            state.savePost = nil
            state.savedToastKind = .saved
            state.savedToastID = (state.savedToastID ?? 0) + 1
            return .none

        case .savePostFailed:
            // TODO: 저장 실패 UI 미정(백엔드 미연동) — 실패 스낵바·재시도 정책 확정 후 붙인다.
            //   지금은 시트를 저장 전 상태로 되돌려 다시 시도할 수 있게만 한다.
            state.savePost?.isSaving = false
            return .none

        case .sharedToOtherRooms:
            // 홈 저장과 같은 토스트 자리를 쓰지만 문구는 [SYS-003] 쪽이다(place-detail 2.2.0 TS-033).
            state.savedToastKind = .shared
            state.savedToastID = (state.savedToastID ?? 0) + 1
            return .none

        case .dismissSavedToast(let id):
            // 이 타이머가 띄운 그 토스트일 때만 지운다 — 2초가 도는 사이 새로 저장하면
            // 이전 타이머의 dismiss 가 방금 뜬 토스트를 지우는 걸 막는다.
            if state.savedToastID == id {
                state.savedToastID = nil
            }
            return .none
        }
    }
}
