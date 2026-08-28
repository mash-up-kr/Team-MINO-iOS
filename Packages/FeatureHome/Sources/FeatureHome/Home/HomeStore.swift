import Domain
import MVI

/// 홈 진입 화면 상태.
public struct HomeState: Equatable {
    public var rooms: [Room]
    public var isLoading: Bool
    public var errorMessage: String?
    /// 현재 조회 기준(필터 칩). 덱을 다 넘기면 다음 기준으로 자동 전환된다.
    public var selectedFilter: PinFilter
    /// 기준별로 받아 둔 덱(캐시). 칩을 오가도 재조회 없이 이어 본다 —
    /// 소진 시 다음 칩, 첫 카드에서 뒤로 가면 이전 칩의 마지막 카드로 이어지는 정책 때문에
    /// 앞뒤로 오가는 일이 잦아 매번 다시 받으면 화면이 비었다 채워진다.
    public var decks: [PinFilter: [Pin]]
    /// 다른 기준의 덱을 받아오는 중인지. 받는 동안에는 빈 상태·소진 화면을 띄우지 않는다(깜빡임 방지).
    public var isDeckLoading: Bool
    /// 현재 맨 앞 카드 인덱스
    public var currentCardIndex: Int
    /// 방별 "더 보기" 페이지 커서(roomID → page). 더 보기마다 +1 해 UseCase 에 넘긴다(다음 페이지 조회).
    public var roomPages: [String: Int]
    /// 방 선택 바텀 시트 표시 여부 (뱃지·캐릭터 탭으로 열림).
    public var isRoomListPresented: Bool
    /// 방 변경 직후 뜨는 툴팁이 가리키는 방의 id (nil = 숨김). 5초 후 자동으로 nil 이 된다.
    /// 표시 문구(방 이름)는 뷰가 이 id 로 rooms 에서 파생한다 — 이름이 같은 방도 안정적으로 식별하려 id 로 든다.
    public var changedRoomToastID: String?
    /// "곧 …으로 이동해요!" 예고 툴팁이 붙은 기준 (nil = 숨김). 현재 기준 덱의 남은 카드가 2장 이하가 되면
    /// 뜨고 3초 후 서서히 사라진다 (Figma 002-2-3 ②). 표시 문구는 뷰가 이 값에서 파생한다 —
    /// 다음 기준이 있으면 그 칩 이름, 마지막 기준이면 "다음 방". 기준을 들고 있어야 3초 타이머가 도는 사이 기준이 바뀌어도
    /// 이전 타이머가 새 툴팁을 지우지 않는다([[changedRoomToastID]] 와 같은 방어).
    public var deckEndingToastFilter: PinFilter?
    /// 홈 사용 가이드(좌우 스와이프 안내) 표시 여부. 최초 진입 1회만 뜬다(Figma 「홈 사용 가이드」).
    public var isGuidePresented: Bool
    /// 방 리스트에서 명시적으로 고른 방 (nil = 미선택). 표시할 카드가 없을 때(빈 방들) 현재 방을 정하는 근거 —
    /// 카드가 있을 땐 덱의 맨 앞 카드가 현재 방을 정하므로 이 값은 쓰이지 않는다.
    public var selectedRoomID: String?
    /// 게시물 저장 시트 상태 (nil = 닫힘). 카드 더보기 메뉴 "다른 방 저장" 으로 열린다.
    public var savePost: SavePostState?
    /// 저장 완료 토스트(Figma 013-2)의 식별자 (nil = 숨김). 저장할 때마다 1씩 올라가
    /// 뷰의 자동 dismiss 타이머가 매번 새로 시작된다 — 연속 저장에서 앞 타이머가 뒤 토스트를 지우지 않게
    /// dismiss action 이 이 id 를 실어 보낸다([[changedRoomToastID]] 와 같은 방어).
    public var savedToastID: Int?

    public init(
        rooms: [Room] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        selectedFilter: PinFilter = .recommended,
        pins: [Pin] = [],
        isDeckLoading: Bool = false,
        currentCardIndex: Int = 0,
        roomPages: [String: Int] = [:],
        isRoomListPresented: Bool = false,
        changedRoomToastID: String? = nil,
        deckEndingToastFilter: PinFilter? = nil,
        isGuidePresented: Bool = false,
        selectedRoomID: String? = nil,
        savePost: SavePostState? = nil,
        savedToastID: Int? = nil
    ) {
        self.rooms = rooms
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedFilter = selectedFilter
        self.decks = pins.isEmpty ? [:] : [selectedFilter: pins]
        self.isDeckLoading = isDeckLoading
        self.currentCardIndex = currentCardIndex
        self.roomPages = roomPages
        self.isRoomListPresented = isRoomListPresented
        self.changedRoomToastID = changedRoomToastID
        self.deckEndingToastFilter = deckEndingToastFilter
        self.isGuidePresented = isGuidePresented
        self.selectedRoomID = selectedRoomID
        self.savePost = savePost
        self.savedToastID = savedToastID
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

    /// 현재 방(뱃지·방 리스트 선택 표시의 기준). 카드가 있으면 맨 앞 카드가 속한 방(넘기면 그 방으로 바뀜),
    /// 카드가 없으면(빈 방들) 방 리스트에서 고른 방(selectedRoomID) — 없으면 첫 방(내 장소).
    /// 덱을 끝까지 넘겨 인덱스가 덱 밖으로 나간 뒤([[hasViewedAllPlaces]])에도 뱃지는 마지막으로 본 방을
    /// 유지해야 하므로 인덱스를 덱 안으로 클램프해서 찾는다(안 하면 소진 순간 뱃지가 첫 방으로 튄다).
    public var currentRoom: Room? {
        if !pins.isEmpty {
            let roomID = pins[min(currentCardIndex, pins.count - 1)].roomID
            return rooms.first { $0.id == roomID } ?? rooms.first
        }
        return rooms.first { $0.id == selectedRoomID } ?? rooms.first
    }

    /// 모든 방의 장소를 끝까지 넘겼는지 (Figma 002-3 「모든 카드를 다 봤을 때」).
    /// 마지막 카드에서 한 번 더 넘기면 인덱스가 덱 밖(pins.count)으로 나가 이 상태가 된다 —
    /// 본문이 소진 일러스트로 바뀌고 플로팅 CTA 가 "장소 더 보기"(전 방 다음 페이지)로 바뀐다.
    public var hasViewedAllPlaces: Bool { isCurrentDeckExhausted && selectedFilter.next == nil }

    /// 현재 기준의 덱을 끝까지 넘겼는지(다음 기준 유무와 무관). 다음 기준이 남아 있으면 소진 화면 대신
    /// 그 기준으로 자동 전환한다 — 그래서 화면 판정([[hasViewedAllPlaces]])과 분리해 둔다.
    var isCurrentDeckExhausted: Bool { !pins.isEmpty && currentCardIndex >= pins.count }

    /// 첫 카드에서 뒤로 넘겨 이전 기준으로 돌아갈 수 있는지 — 첫 기준(`recommended`)에서만 false.
    /// 앞으로 소진되면 다음 기준으로 넘어가는 것([[isCurrentDeckExhausted]])의 반대 방향이다.
    public var canReturnToPreviousFilter: Bool { selectedFilter.previous != nil }

    /// 뒤로 돌아갔을 때 맨 앞에 올 카드 — 이전 기준 덱의 마지막 카드. 그 기준을 아직 받아 두지 않았으면 nil
    /// (전환은 그대로 일어나고, 덱을 받는 동안 복귀 애니메이션에 얹을 카드만 없다).
    public var previousDeckLastPin: Pin? {
        guard let previous = selectedFilter.previous else { return nil }
        return decks[previous]?.last
    }

    /// 현재 기준 덱에서 (현재 카드 포함) 아직 넘기지 않은 카드 수. 덱 끝 예고 툴팁([[deckEndingToastFilter]])
    /// 판단에 쓴다 — 방 구간이 아니라 **덱 전체** 기준이라 다음 기준으로 넘어가기 직전에만 걸린다.
    /// 덱을 다 넘겨 인덱스가 덱 밖으로 나가면([[isCurrentDeckExhausted]]) 0 이다.
    public var remainingInCurrentDeck: Int { max(0, pins.count - currentCardIndex) }

    /// 현재 맨 앞 카드가 속한 방에서 (현재 카드 포함) 아직 넘기지 않은 카드 수.
    /// "이 방 장소 더 보기" 버튼 노출 판단에 쓴다 — 덱 전체가 아니라 현재 방 구간 기준이라, 방마다 끝자락에서 뜬다.
    /// 덱을 다 넘긴 뒤([[hasViewedAllPlaces]])엔 0 이다 — 그 상태의 CTA 는 이 값이 아니라 소진 여부로 정한다.
    public var remainingInCurrentRoom: Int {
        guard pins.indices.contains(currentCardIndex) else { return 0 }
        let roomID = pins[currentCardIndex].roomID
        let end = pins[currentCardIndex...].firstIndex { $0.roomID != roomID } ?? pins.count
        return end - currentCardIndex
    }
}

/// 게시물 저장 시트(Figma 013-1-3) 상태. 시트가 홈 화면 안에서 열고 닫히므로 별도 Store 없이
/// 홈 상태의 한 조각으로 든다 — 저장 완료 토스트가 시트가 닫힌 **뒤** 홈 위에 뜨기 때문에
/// 두 상태가 같은 reduce 안에 있어야 이어진다.
public struct SavePostState: Equatable {
    /// 저장하려는 장소(카드).
    public var pinID: PinID
    /// 이 장소가 이미 들어 있는 방. 체크된 채 비활성이고 `selectedRoomIDs` 와 섞지 않는다 —
    /// 섞으면 "이미 저장된 방만 있는" 상태에서 저장 버튼이 켜진다.
    public var alreadySavedRoomIDs: Set<String>
    /// 사용자가 이번에 새로 고른 방.
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

    public var canSubmit: Bool { !selectedRoomIDs.isEmpty && !isSaving }

    /// 체크로 보이는 방 — 이미 저장된 방도 체크 상태다(Figma 013-1-2).
    public var checkedRoomIDs: Set<String> { alreadySavedRoomIDs.union(selectedRoomIDs) }
}

public enum HomeAction: Equatable {
    case load
    case loaded([Room])
    case loadFailed(DomainError)
    case selectFilter(PinFilter)
    /// 필터가 바뀌어(직접 선택·소진 자동 전환·뒤로 돌아가기) 새로 받은 덱과, 그 덱의 어느 끝에서 시작할지.
    /// `for` 는 이 응답이 **어느 기준의 것인지** — 칩을 연속으로 눌러 응답이 엇갈려 도착해도 제 슬롯에 담기게 한다.
    case filterPinsLoaded(pins: [Pin], entry: DeckEntry, for: PinFilter)
    /// 필터 전환용 덱 조회 실패 — 바꾸려던 기준을 되돌리고 기존 덱을 그대로 유지한다.
    /// 연관값은 실패한 조회의 기준, 되돌릴 기준, 전환 직전의 카드 인덱스.
    case filterPinsLoadFailed(for: PinFilter, revertTo: PinFilter, index: Int)
    case tapCreateRoom
    /// 초기 로드 결과 — 핀 목록과, 이어 볼 방(마지막으로 본 방) id. 최초 실행이면 startRoomID 가 nil.
    case pinsLoaded(pins: [Pin], startRoomID: String?)
    /// "이 방 장소 더 보기" 결과 — 해당 방 구간을 이 핀들로 교체한다.
    case morePlacesLoaded(roomID: String, pins: [Pin])
    case swipeForward
    case swipeBackward
    case tapCard(PinID)
    /// 카드 덱 하단 "이 방 장소 더 보기" 버튼 탭 (동작 미정 — 팀 논의 후 결정)
    case tapMorePlaces
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
    /// 방 변경 툴팁 숨기기 (선택 5초 후 자동 발생). 연관값은 이 타이머가 세운 방의 id —
    /// 5초가 도는 사이 다른 방으로 바꾸면 이전 타이머가 새 방 툴팁을 지우지 않도록 방어한다.
    case dismissRoomToast(String)
    /// 덱 끝 예고 툴팁 숨기기 (노출 3초 후 자동 발생). 연관값은 이 타이머가 띄운 툴팁의 기준 —
    /// 3초가 도는 사이 기준이 바뀌면 이전 타이머가 새 툴팁을 지우지 않도록 방어한다.
    case dismissDeckEndingToast(PinFilter)
    /// 카드 더보기 메뉴 "다른 방 저장" 탭 → 게시물 저장 시트 열기
    case tapSaveToOtherRoom(PinID)
    /// 게시물 저장 시트 닫기 (스와이프 dismiss 포함)
    case dismissSavePost
    case toggleSavePostRoom(String)
    case tapSavePost
    /// 저장 작업이 끝남 → 시트를 닫고 완료 토스트를 띄운다.
    case savePostFinished
    /// 저장 실패 — 시트를 저장 전 상태로 되돌린다.
    case savePostFailed
    /// 저장 완료 토스트 숨기기 (노출 2초 후 자동 발생). 연관값은 이 타이머가 띄운 토스트의 id.
    case dismissSavedToast(Int)
}

public enum HomeNav: Equatable, Sendable {
    case goToCreateRoom
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

/// 새 기준의 덱에 어느 끝으로 들어가는지 — 앞으로 넘어가면 첫 카드, 뒤로 돌아가면 마지막 카드.
public enum DeckEntry: Equatable, Sendable {
    case first
    case last

    func index(in pins: [Pin]) -> Int {
        switch self {
        case .first: 0
        case .last: max(0, pins.count - 1)
        }
    }
}

/// 기준을 바꾼다. 이미 받아 둔 덱이 있으면 재조회 없이 즉시 전환하고(앞뒤로 오갈 때 화면이 비지 않는다),
/// 없으면 받아와 filterPinsLoaded 로 되돌린다. 실패도 filterPinsLoadFailed 로 되돌려 기준을 원위치시킨다 —
/// 성공했을 때만 되돌리면 isDeckLoading 이 꺼지지 않아 화면이 스피너에 영구히 멈춘다.
private func switchFilter(
    to filter: PinFilter,
    entering entry: DeckEntry,
    state: inout HomeState,
    fetchPins: FetchPinsUseCase
) -> Effect<HomeAction, HomeNav> {
    let previousFilter = state.selectedFilter
    let previousIndex = state.currentCardIndex
    state.selectedFilter = filter
    // 전환하는 순간 지난 기준의 예고 툴팁은 할 말을 잃는다("곧 최신순으로" 를 최신순에서 띄우고 있게 된다).
    state.deckEndingToastFilter = nil
    if let cached = state.decks[filter], !cached.isEmpty {
        state.currentCardIndex = entry.index(in: cached)
        // 앞으로 넘어와 첫 카드에 선 경우만 예고한다 — 뒤로 돌아가 마지막 카드에 선 것(.last)은
        // 사용자가 방금 떠나온 길이라 "곧 …으로 이동해요"가 안내가 아니라 잔소리가 된다.
        if entry == .first { announceDeckEndingIfNeeded(&state) }
        return .none
    }
    state.isDeckLoading = true   // 받는 동안 빈 상태·소진 화면이 끼어들지 않게 한다
    let rooms = state.rooms
    return .run { send in
        do {
            let pins = try await fetchPins.execute(rooms: rooms, filter: filter)
            send(.filterPinsLoaded(pins: pins, entry: entry, for: filter))
        } catch {
            send(.filterPinsLoadFailed(for: filter, revertTo: previousFilter, index: previousIndex))
        }
    }
}

/// 덱 끝 예고 툴팁("곧 …으로 이동해요!")을 세운다 — 남은 카드가 2장 이하일 때 (Figma 002-2-3 ②).
///
/// 마지막 기준에서도 띄운다 — 시안이 그때 "곧 다음 방으로 이동해요!" 로 다음 방 이동을 예고한다.
/// 스와이프 경로에서는 호출부가 "막 2장이 된 순간"만 걸러 부른다(2→1 에서 다시 뜨지 않게).
private func announceDeckEndingIfNeeded(_ state: inout HomeState) {
    guard !state.pins.isEmpty, state.remainingInCurrentDeck <= 2 else { return }
    state.deckEndingToastFilter = state.selectedFilter
}

/// 현재 방이 바뀌었을 때만 "마지막으로 본 방"을 기록한다(정책 3 — 재실행 시 이어 보기).
/// 결과 action 이 없는 단발 부수효과라 Effect.run 의 send 를 쓰지 않는다.
private func persistIfRoomChanged(
    from previous: String?,
    to state: HomeState,
    using useCase: LastViewedRoomUseCase
) -> Effect<HomeAction, HomeNav> {
    guard let roomID = state.currentRoom?.id, roomID != previous else { return .none }
    return .run { _ in await useCase.save(roomID: roomID) }
}

/// 순수 reduce. UseCase(fetchRooms·fetchPins·lastViewedRoom)는 Effect.run 안에서만 사용한다.
public func homeReducer(
    fetchRooms: FetchRoomsUseCase,
    fetchPins: FetchPinsUseCase,
    lastViewedRoom: LastViewedRoomUseCase,
    homeGuide: HomeGuideUseCase,
    savePin: SavePinToRoomsUseCase
) -> (inout HomeState, HomeAction) -> Effect<HomeAction, HomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            state.errorMessage = nil
            state.roomPages = [:]
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

        case .loaded(let rooms):
            // 홈은 개인방(personal, "내 장소")을 먼저, 그다음 공동방(shared)을 보여준다 — 데이터 순서와
            // 무관하게 항상 이 순서. 공동방 내부 순서는 서버가 준 순서를 그대로 유지(클라 정렬 없음).
            // 뱃지·카드덱·방리스트가 모두 이 order 를 따른다(방리스트에서 개인방이 "방 만들기" 우측 고정).
            let ordered = rooms.filter { $0.type == .personal } + rooms.filter { $0.type == .shared }
            state.rooms = ordered
            let filter = state.selectedFilter   // 조회 기준도 함께 넘긴다(필터링은 서버 몫)
            // isLoading 은 여기서 끄지 않는다 — 핀까지 로드돼야 표시할 카드 유무가 정해지므로,
            // pinsLoaded 에서 끈다. (여기서 끄면 핀 도착 전 빈 상태+CTA 가 한 프레임 깜빡인다)
            return .run { send in
                do {
                    // 정책: 재실행 시 마지막으로 보던 방부터 이어 본다 — 핀과 함께 병렬로 받아 한 액션으로 되돌린다.
                    async let pins = fetchPins.execute(rooms: ordered, filter: filter)
                    async let startRoomID = lastViewedRoom.load()
                    send(.pinsLoaded(pins: try await pins, startRoomID: await startRoomID))
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
            return switchFilter(to: filter, entering: .first, state: &state, fetchPins: fetchPins)

        case .filterPinsLoaded(let pins, let entry, let filter):
            let roomBeforeFilter = state.currentRoom?.id
            // 받아 온 기준의 슬롯에 담는다(state.pins 는 "지금 보는 기준"에 쓰므로 늦게 온 응답이 남의 칸을 덮는다).
            // 이렇게 두면 지나간 기준의 응답도 자기 캐시에 남아, 그 칩으로 돌아갈 때 재조회하지 않는다.
            state.decks[filter] = pins.isEmpty ? nil : pins
            // 화면을 움직이는 건 지금 보고 있는 기준의 응답일 때만. 아니면 다른 기준 덱이 잠깐 앉았다 사라진다.
            guard filter == state.selectedFilter else { return .none }
            state.isDeckLoading = false
            state.currentCardIndex = entry.index(in: pins)
            // 받아 온 덱이 이미 2장 이하면 넘길 새도 없이 다음 기준이 코앞이다 (Figma 002-2-3 「데이터 2개 이하일 때」).
            if entry == .first { announceDeckEndingIfNeeded(&state) }
            return persistIfRoomChanged(from: roomBeforeFilter, to: state, using: lastViewedRoom)

        case .filterPinsLoadFailed(let filter, let previousFilter, let index):
            // 이미 다른 기준으로 옮겨 갔으면 지나간 조회의 실패다 — 되돌리면 지금 화면을 엉뚱하게 끌고 간다.
            guard filter == state.selectedFilter else { return .none }
            // 실패하면 바꾸려던 기준을 되돌려 기존 덱을 계속 보여준다. 기준을 새것으로 둔 채 로딩만 끄면
            // 그 덱이 비어 있어 빈 상태("공동방 만들기")가 뜬다 — 조회가 실패한 건데 장소가 없다고 말하게 된다.
            state.isDeckLoading = false
            state.selectedFilter = previousFilter
            // 소진 자동 전환 경로에선 인덱스가 이미 덱 밖(pins.count)으로 밀려 있어, 그대로 되돌리면
            // 카드 없는 덱 분기에 들어간다. 복구한 덱의 마지막 카드로 클램프해 거기서 다시 넘기면 재시도된다.
            state.currentCardIndex = min(index, max(0, state.pins.count - 1))
            return .none

        case .tapCreateRoom:
            state.isRoomListPresented = false
            return .navigate(.goToCreateRoom)

        case .pinsLoaded(let pins, let startRoomID):
            state.pins = pins
            // 마지막으로 본 방에 카드가 있으면 그 방부터, 없으면(최초 실행·방 삭제·그 방이 비어 스루됨) 첫 방부터.
            if let startRoomID, let start = pins.firstIndex(where: { $0.roomID == startRoomID }) {
                state.currentCardIndex = start
                state.selectedRoomID = startRoomID
            } else {
                state.currentCardIndex = 0
            }
            state.isLoading = false   // 핀까지 도착 → 이제 카드 유무가 확정돼 로딩 종료
            announceDeckEndingIfNeeded(&state)   // 첫 덱부터 2장 이하일 수 있다
            // 정책: 홈 사용 가이드는 최초 진입 1회. 넘길 카드가 있을 때만 띄운다(빈 상태에선 안내가 무의미).
            guard !pins.isEmpty else { return .none }
            return .run { send in
                if await homeGuide.hasSeen() == false { send(.showGuide) }
            }

        case .morePlacesLoaded(let roomID, let newPins):
            // "더 보기" 결과를 해당 방 구간에만 splice 하고 그 방 첫 카드로 이동. 다른 방 구간은 그대로.
            // 결과가 비면(페이지 소진) 기존 카드를 지우지 않는다 — 안 그러면 그 방 덱이 통째로 사라진다.
            guard !newPins.isEmpty else { return .none }
            guard let start = state.pins.firstIndex(where: { $0.roomID == roomID }) else { return .none }
            let end = state.pins[start...].firstIndex(where: { $0.roomID != roomID }) ?? state.pins.count
            state.pins.replaceSubrange(start..<end, with: newPins)
            // FIXME(백엔드 연동): 실 API 지연 중 사용자가 다른 방으로 이동하면, 뒤늦게 온 이 응답이
            //   currentCardIndex 를 roomID 방으로 도로 끌고 간다(레이스). 실물 계약 확인 후
            //   "현재 방이 아직 roomID 일 때만 인덱스 리셋"(또는 in-flight Task 취소)으로 정리한다.
            state.currentCardIndex = start
            announceDeckEndingIfNeeded(&state)   // 페이지가 얼마 안 실려 와 곧 덱이 끝날 수도 있다
            return .none

        case .swipeForward:
            // 마지막 카드에서 한 번 더 넘기면 인덱스가 덱 밖(pins.count)으로 나간다.
            let roomBeforeForward = state.currentRoom?.id
            if state.currentCardIndex < state.pins.count {
                state.currentCardIndex += 1
            }
            // 정책: 한 기준의 카드를 다 넘기면 다음 기준으로 자동 전환하고, 마지막 기준까지 소진하면
            // 그때 소진 화면(002-3)을 띄운다. 데이터 유무와 무관하게 기준만 넘긴다(필터링은 서버 몫).
            if state.isCurrentDeckExhausted, let next = state.selectedFilter.next {
                return switchFilter(to: next, entering: .first, state: &state, fetchPins: fetchPins)
            }
            // 정책: 남은 카드가 2장이 **되는 순간** 다음 기준 전환을 예고한다 (Figma 002-2-3 ②).
            // `<= 2` 가 아니라 `== 2` 인 이유: 3초 뒤 사라진 툴팁이 2→1 한 장 더 넘길 때 다시 뜨지 않게 한다.
            if state.remainingInCurrentDeck == 2 { announceDeckEndingIfNeeded(&state) }
            return persistIfRoomChanged(from: roomBeforeForward, to: state, using: lastViewedRoom)

        case .swipeBackward:
            let roomBeforeBackward = state.currentRoom?.id
            if state.currentCardIndex > 0 {
                state.currentCardIndex -= 1
                return persistIfRoomChanged(from: roomBeforeBackward, to: state, using: lastViewedRoom)
            }
            // 정책: 첫 카드에서 뒤로 넘기면 이전 기준의 **마지막 카드**(마지막 방의 마지막 장소)로 돌아간다.
            // 앞으로 자동 전환된 경로를 그대로 되짚는 이동이라, 첫 기준에서는 더 갈 곳이 없다.
            guard let previous = state.selectedFilter.previous else { return .none }
            return switchFilter(to: previous, entering: .last, state: &state, fetchPins: fetchPins)

        case .tapCard:
            // TODO: 카드 탭 동작 미정(장소 상세 진입 등) — 팀 논의 후 Nav 를 추가한다.
            return .none

        case .tapMorePlaces:
            // 정책: "더 보기" 탭 → 현재 카드가 속한 방의 다음 페이지를 받아 그 방 구간만 교체하고 그 방 첫 카드로 이동.
            // page 커서를 +1 해 UseCase 에 넘기고(mock 은 풀 회전, 실제는 이미 본 장소 뺀 다음 10개), 결과는
            // morePlacesLoaded 로 되돌려 받아 splice 한다 — 데이터 합성은 Effect.run 안에서만(reduce 순수 유지).
            // TODO: "더 보기" 소진(페이지 끝) 시 동작 미정 — 팀 논의 후 결정.
            // FIXME(백엔드 연동): page 커서를 fetch 전에 올려서, 실패해도 전진한다(다음 성공이 한 페이지 건너뜀).
            //   실 API 계약(page 번호 vs cursor 토큰, "다음 있음" 여부 응답) 확인 후 "성공 시에만 커서 확정"
            //   (실패 시 .morePlacesFailed 로 롤백)으로 정리한다. 목은 throw 안 해 지금은 무해.
            guard let room = state.currentRoom else { return .none }
            let page = (state.roomPages[room.id] ?? 0) + 1
            state.roomPages[room.id] = page
            let filter = state.selectedFilter
            return .run { send in
                do {
                    let pins = try await fetchPins.execute(room: room, page: page, filter: filter)
                    send(.morePlacesLoaded(roomID: room.id, pins: pins))
                } catch {
                    // 더 보기 실패는 조용히 무시(기존 카드 유지). 에러 UI 정책 확정 시 처리 추가.
                }
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
            // 툴팁의 5초 표시 시간은 뷰(페이드 애니메이션과 함께)가 관리하고, 여기서는 상태만 세운다.
            let roomBeforeSelect = state.currentRoom?.id
            state.isRoomListPresented = false
            state.selectedRoomID = roomID   // 카드가 없어도(빈 방) 현재 방으로 반영되도록 명시 기록
            if let start = state.pins.firstIndex(where: { $0.roomID == roomID }) {
                state.currentCardIndex = start
            }
            state.changedRoomToastID = roomID   // 식별은 id 로 — 표시 이름은 뷰가 이 id 로 파생한다
            return persistIfRoomChanged(from: roomBeforeSelect, to: state, using: lastViewedRoom)

        case .dismissRoomToast(let roomID):
            // 이 타이머가 세운 그 방 툴팁일 때만(id 일치) 숨긴다. 5초가 도는 사이 방을 바꾸면
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
            // 카드가 지금 속한 방에는 이 장소가 이미 들어 있다 — 체크된 채 비활성으로 뜬다
            // (Figma 002-1 「다른 방 저장 클릭 후 중복 저장 시」).
            // TODO(백엔드 연동): 한 장소가 여러 방에 담길 수 있어 실제 목록은 서버가 준다.
            //   지금은 카드가 속한 방 하나만 알 수 있어 그것만 표시한다.
            let savedRoomID = state.pins.first { $0.id == pinID }?.roomID
            state.savePost = SavePostState(
                pinID: pinID,
                alreadySavedRoomIDs: savedRoomID.map { [$0] } ?? []
            )
            return .none

        case .dismissSavePost:
            // 저장 중 스와이프로 닫아도 막지 않는다 — 시스템 시트는 이미 닫힌 뒤라 상태만 되살리면
            // 시트가 도로 튀어 올라온다. 진행 중인 저장은 그대로 끝나 완료 토스트로 이어진다.
            state.savePost = nil
            return .none

        case .toggleSavePostRoom(let roomID):
            guard var sheet = state.savePost, !sheet.isSaving else { return .none }
            // 이미 저장된 방은 끌 수 없다 — 뷰가 체크박스를 비활성으로 그리지만, 뷰를 고치면 뚫린다.
            guard !sheet.alreadySavedRoomIDs.contains(roomID) else { return .none }
            if sheet.selectedRoomIDs.contains(roomID) {
                sheet.selectedRoomIDs.remove(roomID)
            } else {
                sheet.selectedRoomIDs.insert(roomID)
            }
            state.savePost = sheet
            return .none

        case .tapSavePost:
            // 뷰의 비활성 처리는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다.
            guard var sheet = state.savePost, sheet.canSubmit else { return .none }
            sheet.isSaving = true
            state.savePost = sheet
            let pinID = sheet.pinID
            let roomIDs = sheet.selectedRoomIDs
            return .run { send in
                do {
                    try await savePin.execute(pinID: pinID, roomIDs: roomIDs)
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
