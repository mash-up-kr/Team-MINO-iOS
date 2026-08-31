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
    /// "곧 …으로 이동해요!" 예고 툴팁이 붙은 기준 (nil = 숨김). 현재 기준 덱의 남은 카드가 2장 이하가 되면
    /// 뜨고 3초 후 서서히 사라진다 (Figma 002-2-3 ②). 표시 문구는 뷰가 이 값에서 파생한다 —
    /// 다음 기준이 있으면 그 칩 이름, 마지막 기준이면 "다음 방". 기준을 들고 있어야 3초 타이머가 도는 사이 기준이 바뀌어도
    /// 이전 타이머가 새 툴팁을 지우지 않는다([[changedRoomToastID]] 와 같은 방어).
    public var deckEndingToastFilter: PinFilter?
    /// 홈 사용 가이드(좌우 스와이프 안내) 표시 여부. 최초 진입 1회만 뜬다(Figma 「홈 사용 가이드」).
    public var isGuidePresented: Bool
    /// 게시물 저장 시트 상태 (nil = 닫힘). 카드 더보기 메뉴 "다른 방 저장" 으로 열린다.
    public var savePost: SavePostState?
    /// 저장 완료 토스트(Figma 013-2)의 식별자 (nil = 숨김). 저장할 때마다 1씩 올라가
    /// 뷰의 자동 dismiss 타이머가 매번 새로 시작된다 — 연속 저장에서 앞 타이머가 뒤 토스트를 지우지 않게
    /// dismiss action 이 이 id 를 실어 보낸다([[changedRoomToastID]] 와 같은 방어).
    public var savedToastID: Int?
    /// 가까운순 조회의 기준점(내 위치). 그 기준을 처음 고른 순간에 한 번 얻어 들고 있는다 —
    /// 서버가 `sort=nearby` 에 좌표를 요구하고, 매번 다시 측위하면 칩을 오갈 때마다 몇 초씩 걸린다.
    public var myCoordinate: Coordinate?
    /// 내 프로필 아바타 색 — 홈 우상단 마스코트가 이 색의 소품을 단다 (Figma `character/Home_Avatar`).
    /// 아직 못 읽었거나 색을 고른 적 없는 계정이면 nil 이라 소품 없는 기본 마스코트가 뜬다.
    public var myAvatarColor: AvatarColor?
    /// 지금 방을 **사용자가 직접 골랐는가**(홈 방 시트). 아직 그 방의 카드를 한 장도 못 본 상태다.
    ///
    /// 이 동안에는 그 방이 비어 있어도 자동으로 다음 방에 넘기지 않는다 — 지목한 방을 놔두고
    /// 마지막 방까지 끌려가면 사용자는 자기가 어디로 갔는지 알 수 없다. spec 의 "0개인 방을
    /// 건너뛴다"(FR-013)는 **자동 전환이 갈 곳을 고를 때**의 규칙이고, 시트에서 방을 고르면
    /// "**그 방의** 덱이 노출된다"(TS-028)가 따로 있다.
    ///
    /// 방 안에서 정렬을 옮기는 것은 막지 않는다 — 꾹 Pick 이 비어도 그 방의 최신순에 카드가
    /// 있을 수 있어서, 정렬 순회까지 막으면 있는 카드를 못 보여준다.
    var isRoomUserChosen: Bool

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
        deckEndingToastFilter: PinFilter? = nil,
        isGuidePresented: Bool = false,
        savePost: SavePostState? = nil,
        savedToastID: Int? = nil,
        myCoordinate: Coordinate? = nil,
        myAvatarColor: AvatarColor? = nil,
        isRoomUserChosen: Bool = false
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
        self.deckEndingToastFilter = deckEndingToastFilter
        self.isGuidePresented = isGuidePresented
        self.savePost = savePost
        self.savedToastID = savedToastID
        self.myCoordinate = myCoordinate
        self.myAvatarColor = myAvatarColor
        self.isRoomUserChosen = isRoomUserChosen
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
    public var showsEmptyState: Bool { !isLoading && !isDeckLoading && pins.isEmpty }

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

    /// 모든 방의 장소를 끝까지 넘겼는지 (Figma 002-3 「모든 카드를 다 봤을 때」).
    /// 마지막 방의 마지막 미확인 정렬까지 넘겨 인덱스가 덱 밖으로 나가면 이 상태가 된다.
    public var hasViewedAllPlaces: Bool {
        isCurrentDeckExhausted && nextUnviewedFilter == nil && !hasNextRoom
    }

    /// 현재 정렬의 덱을 끝까지 넘겼는지(다음 갈 곳 유무와 무관). 갈 곳이 남아 있으면 소진 화면 대신
    /// 그쪽으로 자동 전환한다 — 그래서 화면 판정([[hasViewedAllPlaces]])과 분리해 둔다.
    var isCurrentDeckExhausted: Bool { !pins.isEmpty && currentCardIndex >= pins.count }

    /// 현재 정렬 덱에서 (현재 카드 포함) 아직 넘기지 않은 카드 수. 덱 끝 예고 툴팁([[deckEndingToastFilter]])
    /// 판단에 쓴다. 덱을 다 넘겨 인덱스가 덱 밖으로 나가면([[isCurrentDeckExhausted]]) 0 이다.
    public var remainingInCurrentDeck: Int { max(0, pins.count - currentCardIndex) }
}

/// `다른 방 저장` 으로 열리는 「홈 방 시트」의 상태 (nil = 닫힘).
///
/// 시트가 홈 화면 안에서 열고 닫히므로 별도 Store 없이 홈 상태의 한 조각으로 든다 —
/// 저장 완료 토스트가 시트가 닫힌 **뒤** 홈 위에 뜨기 때문에 두 상태가 같은 reduce 안에 있어야 이어진다.
///
/// 고른 방을 모아 두는 자리가 없는 것은 시트가 **누르는 즉시 확정**이기 때문이다
/// (FR-018 — 체크박스도 확정 버튼도 두지 않는다).
public struct SavePostState: Equatable {
    /// 저장하려는 장소(카드).
    public var pinID: PinID
    /// 이 장소가 이미 들어 있는 방 — 그리드에서 체크된 채 눌리지 않는다(중복 저장은 서버도 409 로 막는다).
    public var savedRoomID: String?
    public var isSaving: Bool

    public init(pinID: PinID, savedRoomID: String? = nil, isSaving: Bool = false) {
        self.pinID = pinID
        self.savedRoomID = savedRoomID
        self.isSaving = isSaving
    }
}

public enum HomeAction: Equatable {
    case load
    /// 홈 마스코트가 쓸 내 아바타 색을 읽는다. `load` 와 나눠 둔 이유는 둘이 서로를 기다릴 이유가
    /// 없어서다 — 마스코트는 장식이라 방·덱 조회가 늦거나 실패해도 제 색으로 떠야 한다.
    case loadMyAvatar
    case myAvatarLoaded(AvatarColor?)
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
    /// 홈 사용 가이드를 아직 안 봤는지 묻는다(최초 진입 1회 정책). `load` 와 나눠 둔 이유는
    /// 마스코트([[loadMyAvatar]])와 같다 — 가이드가 그리는 카드 덱은 모형이라(``HomeGuideMockDeck``)
    /// 방·덱 조회 결과를 기다릴 이유가 없고, 조회가 늦거나 실패해도 안내는 떠야 한다.
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
    /// 덱 끝 예고 툴팁 숨기기 (노출 3초 후 자동 발생). 연관값은 이 타이머가 띄운 툴팁의 기준 —
    /// 3초가 도는 사이 기준이 바뀌면 이전 타이머가 새 툴팁을 지우지 않도록 방어한다.
    case dismissDeckEndingToast(PinFilter)
    /// 카드 더보기 메뉴 "다른 방 저장" 탭 → 게시물 저장 시트 열기
    case tapSaveToOtherRoom(PinID)
    /// 게시물 저장 시트 닫기 (스와이프 dismiss 포함)
    case dismissSavePost
    /// 「홈 방 시트」에서 방을 고름 → 그 방에 바로 저장한다(누르는 즉시 확정, FR-018).
    case savePostToRoom(String)
    /// 저장 작업이 끝남 → 시트를 닫고 완료 토스트를 띄운다.
    case savePostFinished
    /// 저장 실패 — 시트를 저장 전 상태로 되돌린다.
    case savePostFailed
    /// 저장 완료 토스트 숨기기 (노출 2초 후 자동 발생). 연관값은 이 타이머가 띄운 토스트의 id.
    case dismissSavedToast(Int)
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
    var isRoomUserChosen: Bool

    public init(
        roomIndex: Int,
        filter: PinFilter,
        cardIndex: Int,
        decks: [PinFilter: [Pin]] = [:],
        viewedFilters: Set<PinFilter> = [],
        filterAnchor: PinFilter = .recommended,
        changedRoomToastID: String? = nil,
        isRoomUserChosen: Bool = false
    ) {
        self.roomIndex = roomIndex
        self.filter = filter
        self.cardIndex = cardIndex
        self.decks = decks
        self.viewedFilters = viewedFilters
        self.filterAnchor = filterAnchor
        self.changedRoomToastID = changedRoomToastID
        self.isRoomUserChosen = isRoomUserChosen
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
            isRoomUserChosen: state.isRoomUserChosen
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
    // 옮기는 순간 지난 자리의 예고 툴팁은 할 말을 잃는다("곧 최신순으로" 를 최신순에서 띄우고 있게 된다).
    state.deckEndingToastFilter = nil
    if let cached = state.decks[filter], !cached.isEmpty {
        state.currentCardIndex = 0
        announceDeckEndingIfNeeded(&state)
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
/// 정책: 방 진입 시 우선순위는 꾹 Pick → 최신순 → 가까운순이라 anchor 를 기본으로 되돌린다.
/// 전환 안내로 방 변경 툴팁도 함께 세운다(자동·수동 전환 모두 같은 안내).
private func moveToRoom(
    index: Int,
    revertingTo revert: DeckPosition,
    state: inout HomeState,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase,
    lastViewedRoom: LastViewedRoomUseCase
) -> Effect<HomeAction, HomeNav> {
    guard state.rooms.indices.contains(index) else { return .none }
    state.currentRoomIndex = index
    state.viewedFilters = []
    state.filterAnchor = .recommended
    state.decks = [:]            // 덱 캐시는 방에 딸린 것이다
    state.currentCardIndex = 0
    state.isRoomUserChosen = false   // 자동 전환이 기본값 — 수동 경로(selectRoom)가 뒤에서 세운다
    state.changedRoomToastID = state.rooms[index].id
    return showDeck(
        filter: .recommended, revertingTo: revert, persistingRoom: true,
        state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom
    )
}

/// 현재 정렬의 덱을 다 봤을 때 이어서 갈 곳으로 옮긴다.
/// 정책: 이 방에 미확인 정렬이 남아 있으면 **다음 방으로 가지 않고** 그 정렬로 자동 전환하고,
/// 세 정렬을 모두 확인했을 때만 다음 방으로 넘어간다. 마지막 방까지 끝나면 소진 화면(002-3)에 남는다.
private func advanceAfterDeck(
    state: inout HomeState,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase,
    lastViewedRoom: LastViewedRoomUseCase
) -> Effect<HomeAction, HomeNav> {
    let revert = DeckPosition(state)   // 확인 기록을 넣기 전 자리를 담아 둔다(실패하면 여기로 돌아온다)
    state.viewedFilters.insert(state.selectedFilter)
    if let next = state.nextUnviewedFilter {
        return showDeck(
            filter: next, revertingTo: revert,
            state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom
        )
    }
    guard state.hasNextRoom else { return .none }
    // 사용자가 지목한 방이면 비어 있어도 남는다 — 그 방의 빈 상태를 보여 주고 멈춘다.
    // 정렬 순회는 위에서 이미 끝난 뒤라, 그 방의 세 덱이 모두 비었다는 게 확인된 상태다.
    guard !state.isRoomUserChosen else { return .none }
    return moveToRoom(
        index: state.currentRoomIndex + 1, revertingTo: revert,
        state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom
    )
}

/// 덱 끝 예고 툴팁("곧 …으로 이동해요!")을 세운다 — 남은 카드가 2장 이하일 때 (Figma 002-2-3 ②).
///
/// 문구는 뷰가 "다음에 갈 곳"으로 파생한다 — 미확인 정렬이 남아 있으면 그 칩 이름, 없으면 "다음 방".
/// 갈 곳이 아무것도 없으면(마지막 방의 마지막 정렬) 예고하지 않는다 — 그땐 소진 화면이 답이다.
/// 스와이프 경로에서는 호출부가 "막 2장이 된 순간"만 걸러 부른다(2→1 에서 다시 뜨지 않게).
private func announceDeckEndingIfNeeded(_ state: inout HomeState) {
    guard !state.pins.isEmpty, state.remainingInCurrentDeck <= 2 else { return }
    guard state.nextUnviewedFilter != nil || state.hasNextRoom else { return }
    state.deckEndingToastFilter = state.selectedFilter
}

/// 순수 reduce. UseCase(fetchRooms·fetchHomeCards·lastViewedRoom)는 Effect.run 안에서만 사용한다.
public func homeReducer(
    fetchRooms: FetchRoomsUseCase,
    fetchHomeCards: FetchHomeCardsUseCase,
    currentLocation: CurrentLocationUseCase,
    lastViewedRoom: LastViewedRoomUseCase,
    homeGuide: HomeGuideUseCase,
    savePin: SavePinToRoomsUseCase,
    fetchProfile: FetchProfileUseCase,
    recordPinAccess: RecordPinAccessUseCase
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

        case .loadMyAvatar:
            return .run { send in
                do {
                    send(.myAvatarLoaded(try await fetchProfile.execute().avatarColor))
                } catch is CancellationError {
                    return
                } catch {
                    // 마스코트는 장식이라 조회 실패로 화면을 막지 않는다 — 소품 없는 기본 마스코트로 둔다.
                    send(.myAvatarLoaded(nil))
                }
            }

        case .myAvatarLoaded(let color):
            state.myAvatarColor = color
            return .none

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
            // 빈 정렬은 보여줄 게 없으므로 확인한 것으로 치고 다음 갈 곳으로 넘어간다
            // (가려던 자리가 비었다고 빈 화면을 띄우면, 남은 정렬·방을 못 보고 막힌다).
            guard !pins.isEmpty else {
                return advanceAfterDeck(state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom)
            }
            // 고른 방의 카드를 실제로 봤다 — 이후 이 덱을 소진하면 평소대로 다음 방으로 넘어간다.
            // (표시를 남겨 두면 사용자가 그 방에 영영 갇힌다)
            state.isRoomUserChosen = false
            // 받아 온 덱이 이미 2장 이하면 넘길 새도 없이 다음 자리가 코앞이다 (EC-012).
            announceDeckEndingIfNeeded(&state)
            return .none

        case .deckLoadFailed(let roomID, let filter, let revert):
            // 이미 다른 자리로 옮겨 갔으면 지나간 조회의 실패다 — 되돌리면 지금 화면을 엉뚱하게 끌고 간다.
            guard roomID == state.currentRoom?.id, filter == state.selectedFilter else { return .none }
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
            state.isRoomUserChosen = revert.isRoomUserChosen
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
            // 첫 정렬이 비어 있으면 남은 정렬·방으로 넘어간다(빈 화면에 막히지 않게).
            guard !pins.isEmpty else {
                return advanceAfterDeck(state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom)
            }
            announceDeckEndingIfNeeded(&state)   // 첫 덱부터 2장 이하일 수 있다
            return .none

        case .swipeForward:
            // 마지막 카드에서 한 번 더 넘기면 인덱스가 덱 밖(pins.count)으로 나간다.
            if state.currentCardIndex < state.pins.count {
                state.currentCardIndex += 1
            }
            if state.isCurrentDeckExhausted {
                return advanceAfterDeck(state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom)
            }
            // 정책: 남은 카드가 2장이 **되는 순간** 다음 자리를 예고한다 (Figma 002-2-3 ②).
            // `<= 2` 가 아니라 `== 2` 인 이유: 3초 뒤 사라진 툴팁이 2→1 한 장 더 넘길 때 다시 뜨지 않게 한다.
            if state.remainingInCurrentDeck == 2 { announceDeckEndingIfNeeded(&state) }
            return .none

        case .swipeBackward:
            // 되돌리기는 **현재 덱 안에서 1단계**뿐이다 — 덱이 바뀌면 되돌리기 이력이 초기화되므로
            // 첫 카드에서 더 뒤로 가면 이전 덱이 아니라 아무 일도 일어나지 않는다(EC-001·EC-003).
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
            // 정책: 방 클릭 시 해당 방으로 바로 적용 + 시트 닫기 + 변경 툴팁(moveToRoom 이 함께 세운다).
            // 툴팁의 3초 표시 시간은 뷰(페이드 애니메이션과 함께)가 관리하고, 여기서는 상태만 세운다.
            state.isRoomListPresented = false
            guard let index = state.rooms.firstIndex(where: { $0.id == roomID }) else { return .none }
            // 정책(EC-014): 지금 보고 있는 방을 다시 고르면 시트만 닫고 덱을 다시 구성하지 않는다 —
            // 재구성하면 넘겨 둔 진행 상태가 통째로 날아간다.
            guard index != state.currentRoomIndex else { return .none }
            let effect = moveToRoom(
                index: index, revertingTo: DeckPosition(state),
                state: &state, fetchHomeCards: fetchHomeCards, currentLocation: currentLocation, lastViewedRoom: lastViewedRoom
            )
            state.isRoomUserChosen = true   // moveToRoom 이 false 로 되돌린 뒤라 여기서 세운다
            return effect

        case .dismissRoomToast(let roomID):
            // 이 타이머가 세운 그 방 툴팁일 때만(id 일치) 숨긴다. 3초가 도는 사이 방을 바꾸면
            // 이전 타이머의 dismiss 가 뒤늦게 도착해 새 방 툴팁을 지우는 걸 막는다.
            // id 로 비교하므로 이름이 같은 방들끼리도 정확히 구분된다.
            if state.changedRoomToastID == roomID {
                state.changedRoomToastID = nil
            }
            return .none

        case .dismissDeckEndingToast(let filter):
            // 이 타이머가 세운 그 기준의 툴팁일 때만 숨긴다 — 3초가 도는 사이 기준이 바뀌면
            // 뒤늦게 도착한 dismiss 가 새 기준의 툴팁을 지우는 걸 막는다([[dismissRoomToast]] 와 같은 방어).
            if state.deckEndingToastFilter == filter {
                state.deckEndingToastFilter = nil
            }
            return .none

        case .tapSaveToOtherRoom(let pinID):
            // 정책(FR-005): 메뉴를 닫고 「홈 방 시트」를 연다. 덱의 진행 상태는 건드리지 않는다.
            // 카드가 지금 속한 방에는 이 장소가 이미 들어 있어 그 칸만 체크·비활성으로 뜬다.
            // TODO(백엔드 연동): 한 장소가 여러 방에 담길 수 있어 실제 목록은 서버가 준다.
            //   지금은 카드가 속한 방 하나만 알 수 있어 그것만 표시한다.
            state.savePost = SavePostState(
                pinID: pinID,
                savedRoomID: state.pins.first { $0.id == pinID }?.roomID
            )
            return .none

        case .dismissSavePost:
            // 저장 중 스와이프로 닫아도 막지 않는다 — 시스템 시트는 이미 닫힌 뒤라 상태만 되살리면
            // 시트가 도로 튀어 올라온다. 진행 중인 저장은 그대로 끝나 완료 토스트로 이어진다.
            state.savePost = nil
            return .none

        case .savePostToRoom(let roomID):
            guard var sheet = state.savePost, !sheet.isSaving else { return .none }
            // 이미 담긴 방은 고를 수 없다 — 뷰가 그 칸을 눌리지 않게 그리지만, 뷰를 고치면 뚫린다.
            guard roomID != sheet.savedRoomID else { return .none }
            sheet.isSaving = true
            state.savePost = sheet
            let pinID = sheet.pinID
            return .run { send in
                do {
                    try await savePin.execute(pinID: pinID, roomIDs: [roomID])
                    send(.savePostFinished)
                } catch {
                    send(.savePostFailed)
                }
            }

        case .savePostFinished:
            // 시트를 먼저 닫고 그 자리에 토스트만 남긴다(Figma 013-2).
            state.savePost = nil
            state.savedToastID = (state.savedToastID ?? 0) + 1
            return .none

        case .savePostFailed:
            // TODO: 저장 실패 UI 미정(백엔드 미연동) — 실패 스낵바·재시도 정책 확정 후 붙인다.
            //   지금은 시트를 저장 전 상태로 되돌려 다시 시도할 수 있게만 한다.
            state.savePost?.isSaving = false
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
