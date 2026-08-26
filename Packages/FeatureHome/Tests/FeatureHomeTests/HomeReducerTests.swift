import Foundation
import Domain
import MVITestSupport
import Testing
@testable import FeatureHome

private let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)

private let fixtureRooms = [
    Room(
        id: "1", type: .shared, name: "맛집 탐방", description: nil,
        color: "#FF6B6B", ownerId: "owner-1", inviteCode: "FOOD2024",
        createdAt: fixtureDate, pinCount: 3, memberCount: 2, users: []
    ),
    Room(
        id: "2", type: .shared, name: "데이트 코스", description: nil,
        color: "#4ECDC4", ownerId: "owner-1", inviteCode: "DATE2024",
        createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
    ),
]

private let fixturePins: [Pin] = (0..<3).map { i in
    Pin(
        id: PinID("pin-\(i)"),
        roomID: "1",
        category: [.popularAmongFriends, .manyStories, .savedByMany][i],
        title: "장소 \(i)",
        address: "주소 \(i)",
        createdAt: fixtureDate
    )
}

private struct StubFetchRooms: FetchRoomsUseCase {
    var result: Result<[Room], DomainError> = .success(fixtureRooms)
    func execute() async throws -> [Room] {
        switch result {
        case .success(let rooms): return rooms
        case .failure(let error): throw error
        }
    }
}

/// 핀 조회 스텁 — 초기 로드(`all`)와 "더 보기"(`more`)를 각각 제어해 결과를 결정적으로 단언한다.
private struct StubFetchPins: FetchPinsUseCase {
    var all: [Pin] = []
    var more: [Pin] = []
    func execute(rooms: [Room], filter: PinFilter) async throws -> [Pin] { all }
    func execute(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] { more }
}

/// 홈 가이드 스파이 — 이미 본 상태를 주입하고, 기록(markSeen) 호출을 센다.
private actor SpyHomeGuide: HomeGuideUseCase {
    private let seen: Bool
    private(set) var markedSeen = 0

    init(seen: Bool = true) { self.seen = seen }

    func hasSeen() async -> Bool { seen }
    func markSeen() async { markedSeen += 1 }
}

/// 마지막으로 본 방 스파이 — 저장된 값을 돌려주고(load), 기록 호출(save)을 모은다.
private actor SpyLastViewedRoom: LastViewedRoomUseCase {
    private let stored: String?
    private(set) var saved: [String] = []

    init(stored: String? = nil) { self.stored = stored }

    func load() async -> String? { stored }
    func save(roomID: String) async { saved.append(roomID) }
}

/// 저장 스파이 — 어떤 장소를 어느 방들에 저장했는지 모은다.
private actor SpySavePin: SavePinToRoomsUseCase {
    private(set) var saved: [(pinID: PinID, roomIDs: Set<String>)] = []

    func execute(pinID: PinID, roomIDs: Set<String>) async throws {
        saved.append((pinID, roomIDs))
    }
}

/// 저장이 항상 실패하는 스텁 — 실패 경로(시트 되돌리기)를 검증한다.
private struct ThrowingSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws { throw DomainError.unknown }
}

/// 핀 조회가 항상 실패하는 스텁 — 실패 경로(로드 실패 라우팅 / 더 보기 무시)를 검증한다.
private struct ThrowingFetchPins: FetchPinsUseCase {
    var error: DomainError = .unknown
    func execute(rooms: [Room], filter: PinFilter) async throws -> [Pin] { throw error }
    func execute(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] { throw error }
}

@MainActor
struct HomeReducerTests {
    private func makeStore(
        _ fetchRooms: FetchRoomsUseCase = StubFetchRooms(),
        fetchPins: FetchPinsUseCase = StubFetchPins(),
        lastViewedRoom: LastViewedRoomUseCase = SpyLastViewedRoom(),
        homeGuide: HomeGuideUseCase = SpyHomeGuide(seen: true),   // 기본은 "이미 본" — 가이드 없는 흐름
        savePin: SavePinToRoomsUseCase = SpySavePin(),
        state: HomeState = HomeState()
    ) -> TestStore<HomeState, HomeAction, HomeNav> {
        TestStore(
            state,
            reduce: homeReducer(
                fetchRooms: fetchRooms,
                fetchPins: fetchPins,
                lastViewedRoom: lastViewedRoom,
                homeGuide: homeGuide,
                savePin: savePin
            )
        )
    }

    // MARK: - Load

    @Test("L2 — load 성공 시 rooms 를 반영한다")
    func load_success() async {
        let store = makeStore()
        store.exhaustive = false
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixtureRooms)) {
            $0.rooms = fixtureRooms
            // isLoading 은 여기서 안 꺼진다 — 핀까지 로드돼야(pinsLoaded) 로딩 종료
        }
        // .loaded 가 트리거하는 .pinsLoaded 는 mock 핀이라 정확한 값 예측 불가
        // → exhaustive=false 로 pending 무시, pins 로드는 pinsLoaded 테스트에서 별도 검증
    }

    @Test("L2 — load 는 개인방을 먼저, 그다음 공동방 순서로 반영한다(데이터 순서 무관)")
    func load_ordersPersonalFirst() async {
        let personal = Room(
            id: "0", type: .personal, name: "내 장소", description: nil,
            color: "#00BDDE", ownerId: "owner-1", inviteCode: "MYROOM",
            createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
        )
        // 데이터는 공동방이 먼저, 개인방이 뒤에 오도록 준다 → 리듀서가 개인방을 맨 앞으로 재정렬해야 한다.
        let store = makeStore(StubFetchRooms(result: .success(fixtureRooms + [personal])))
        store.exhaustive = false   // .loaded 가 트리거하는 .pinsLoaded(mock)는 무시
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixtureRooms + [personal])) {
            $0.rooms = [personal] + fixtureRooms   // 개인방 맨 앞, 공동방은 준 순서 유지
            // isLoading 은 pinsLoaded 에서 꺼진다
        }
    }

    @Test("L2 — load 실패 시 errorMessage 를 채우고 로딩을 끈다")
    func load_failure() async {
        let store = makeStore(StubFetchRooms(result: .failure(.unknown)))
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loadFailed(.unknown)) {
            $0.isLoading = false
            $0.errorMessage = "unknown"
        }
        store.finish()
    }

    @Test("L2 — 방은 성공해도 핀 조회가 실패하면 loadFailed 로 흘러 로딩을 끈다")
    func load_pinsFailure() async {
        // rooms 는 성공, pins 조회만 실패 → 리듀서가 .loaded 뒤 pins 에러를 loadFailed 로 라우팅
        let store = makeStore(StubFetchRooms(), fetchPins: ThrowingFetchPins())
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixtureRooms)) {
            $0.rooms = fixtureRooms   // 방은 반영, 로딩은 아직(핀 대기)
        }
        await store.receive(.loadFailed(.unknown)) {
            $0.isLoading = false
            $0.errorMessage = "unknown"
        }
        store.finish()
    }

    // MARK: - Empty state

    @Test("표시할 카드가 0장이면 showsEmptyState 가 true (방·공동방 유무 무관)")
    func showsEmptyState_true_whenNoPins() {
        // 방(개인방)은 있지만 볼 장소가 0 → 빈 상태
        let state = HomeState(rooms: fixtureRooms, isLoading: false, pins: [])
        #expect(state.showsEmptyState)
    }

    @Test("표시할 카드가 있으면 showsEmptyState 가 false")
    func showsEmptyState_false_whenHasPins() {
        let state = HomeState(rooms: fixtureRooms, pins: fixturePins)
        #expect(!state.showsEmptyState)
    }

    @Test("로딩 중이면 카드가 0장이어도 showsEmptyState 가 false (로딩 우선)")
    func showsEmptyState_false_whileLoading() {
        let state = HomeState(isLoading: true, pins: [])
        #expect(!state.showsEmptyState)
    }

    @Test("showsRoomIdentity — 개인방만 비면 false(로고·마스코트 숨김), 공동방 있거나 장소 있으면 true(방 칩·마스코트)")
    func showsRoomIdentity_rules() {
        let personal = Room(
            id: "0", type: .personal, name: "내 장소", description: nil,
            color: "#00BDDE", ownerId: "o", inviteCode: "MY",
            createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
        )
        // 개인방만 있고 비었음 → 로고(GGUK)·마스코트 숨김
        #expect(!HomeState(rooms: [personal], pins: []).showsRoomIdentity)
        // 공동방이 있으면 내 장소·공동방 모두 비었어도 → 방 칩·마스코트 유지(방 리스트 전환 가능)
        #expect(HomeState(rooms: [personal] + fixtureRooms, pins: []).showsRoomIdentity)
        // 표시할 장소가 있으면 → 방 칩·마스코트
        #expect(HomeState(rooms: fixtureRooms, pins: fixturePins).showsRoomIdentity)
        // 지금 칩의 덱만 비고 다른 기준엔 장소가 있으면 → 유지. 숨기면 방을 바꿀 유일한 진입점이 사라진다
        var otherFilterOnly = HomeState(rooms: [personal], selectedFilter: .nearby, pins: [])
        otherFilterOnly.decks[.latest] = fixturePins
        #expect(otherFilterOnly.showsRoomIdentity)
    }

    // MARK: - Filter

    @Test("L2 — selectFilter 는 기준을 바꾸고 그 기준의 덱을 새로 받아 첫 카드부터 보여준다")
    func selectFilter_reloadsDeck() async {
        let filtered = multiRoomPins()
        let store = makeStore(
            fetchPins: StubFetchPins(all: filtered),
            state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2)
        )
        await store.send(.selectFilter(.nearby)) {
            $0.selectedFilter = .nearby
            $0.isDeckLoading = true      // 아직 안 받아 본 기준이라 조회한다
        }
        await store.receive(.filterPinsLoaded(pins: filtered, entry: .first, for: .nearby)) {
            $0.isDeckLoading = false
            $0.pins = filtered
            $0.currentCardIndex = 0
        }
        store.finish()
    }

    @Test("L2 — 필터 덱 조회가 실패하면 기준을 되돌리고 로딩을 꺼 기존 덱을 계속 보여준다")
    func selectFilter_revertsOnFetchFailure() async {
        let store = makeStore(
            fetchPins: ThrowingFetchPins(),
            state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2)
        )
        await store.send(.selectFilter(.nearby)) {
            $0.selectedFilter = .nearby
            $0.isDeckLoading = true
        }
        await store.receive(.filterPinsLoadFailed(for: .nearby, revertTo: .recommended, index: 2)) {
            $0.isDeckLoading = false
            $0.selectedFilter = .recommended   // 못 받았으니 원래 기준으로
        }
        #expect(store.currentState.pins == fixturePins)   // 기존 덱 유지
        #expect(!store.currentState.showsEmptyState)      // 조회 실패가 "장소 없음"으로 새지 않는다
        store.finish()
    }

    @Test("L2 — 첫 카드에서 뒤로 넘기면 이전 기준의 마지막 카드로 돌아간다")
    func swipeBackward_returnsToPreviousFilterLastCard() async {
        let previousDeck = multiRoomPins()   // 방1 3장 + 방2 2장
        let store = makeStore(
            fetchPins: StubFetchPins(all: previousDeck),
            state: HomeState(rooms: fixtureRooms, selectedFilter: .latest, pins: fixturePins)
        )
        await store.send(.swipeBackward) {
            $0.selectedFilter = .recommended   // 최신순 → 꾹 Pick
            $0.isDeckLoading = true
        }
        await store.receive(.filterPinsLoaded(pins: previousDeck, entry: .last, for: .recommended)) {
            $0.isDeckLoading = false
            $0.pins = previousDeck
            $0.currentCardIndex = previousDeck.count - 1   // 마지막 방의 마지막 카드
        }
        #expect(store.currentState.currentRoom?.id == "2")   // 마지막 방
        store.finish()
    }

    @Test("L1 — 첫 기준의 첫 카드에서 뒤로 넘기면 아무 일도 하지 않는다")
    func swipeBackward_atFirstFilterDoesNothing() async {
        let store = makeStore(
            state: HomeState(rooms: fixtureRooms, selectedFilter: .recommended, pins: fixturePins)
        )
        await store.send(.swipeBackward)
        store.finish()
    }

    @Test("L2 — 한 번 받아 둔 기준으로 돌아갈 땐 재조회 없이 즉시 전환한다")
    func switchingBackToCachedFilterSkipsFetch() async {
        let latestDeck = multiRoomPins()
        let store = makeStore(
            fetchPins: StubFetchPins(all: latestDeck),
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .recommended,
                pins: fixturePins, currentCardIndex: fixturePins.count - 1
            )
        )
        // 소진 → 최신순 덱을 받아 캐시에 남는다
        await store.send(.swipeForward) {
            $0.currentCardIndex = fixturePins.count
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.filterPinsLoaded(pins: latestDeck, entry: .first, for: .latest)) {
            $0.isDeckLoading = false
            $0.pins = latestDeck
            $0.currentCardIndex = 0
        }
        // 뒤로 → 꾹 Pick 은 이미 받아 둔 덱이라 조회 없이 마지막 카드로
        await store.send(.swipeBackward) {
            $0.selectedFilter = .recommended
            $0.currentCardIndex = fixturePins.count - 1
        }
        store.finish()   // 추가 effect 없음 = 재조회 안 함
    }

    @Test("previousDeckLastPin — 받아 둔 이전 기준의 마지막 카드(복귀 애니메이션이 얹을 카드)")
    func previousDeckLastPin_exposesCachedPreviousDeckTail() async {
        let latestDeck = multiRoomPins()
        let store = makeStore(
            fetchPins: StubFetchPins(all: latestDeck),
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .recommended,
                pins: fixturePins, currentCardIndex: fixturePins.count - 1
            )
        )
        // 첫 기준에서는 돌아갈 곳이 없다 → 뷰가 좌드래그를 막는 근거
        #expect(!store.currentState.canReturnToPreviousFilter)
        #expect(store.currentState.previousDeckLastPin == nil)

        await store.send(.swipeForward) {   // 소진 → 최신순으로 자동 전환
            $0.currentCardIndex = fixturePins.count
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.filterPinsLoaded(pins: latestDeck, entry: .first, for: .latest)) {
            $0.isDeckLoading = false
            $0.pins = latestDeck
            $0.currentCardIndex = 0
        }
        #expect(store.currentState.canReturnToPreviousFilter)
        #expect(store.currentState.previousDeckLastPin == fixturePins.last)
        store.finish()
    }

    @Test("previousDeckLastPin — 아직 안 받아 둔 기준이면 nil (전환은 되고 카드만 못 얹는다)")
    func previousDeckLastPin_nilWhenPreviousDeckNotFetched() {
        // 꾹 Pick 을 건너뛰고 최신순부터 본 상태 — 이전 기준 덱이 캐시에 없다
        let state = HomeState(rooms: fixtureRooms, selectedFilter: .latest, pins: fixturePins)
        #expect(state.canReturnToPreviousFilter)
        #expect(state.previousDeckLastPin == nil)
    }

    @Test("L1 — 지나간 기준의 응답은 화면을 움직이지 않고 제 캐시에만 담긴다")
    func filterPinsLoaded_staleResponseOnlyFillsItsOwnCache() async {
        let latestDeck = multiRoomPins()
        let store = makeStore(
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .nearby, pins: [], isDeckLoading: true
            )
        )
        // 최신순으로 갔다가 곧바로 가까운순으로 옮긴 뒤, 최신순 응답이 뒤늦게 도착한 상황
        await store.send(.filterPinsLoaded(pins: latestDeck, entry: .first, for: .latest)) {
            $0.decks[.latest] = latestDeck   // 캐시엔 남는다 — 그 칩으로 돌아가면 재조회하지 않는다
        }
        #expect(store.currentState.isDeckLoading)   // 기다리는 건 여전히 가까운순 응답
        store.finish()
    }

    @Test("L1 — 지나간 기준의 조회 실패는 지금 기준을 되돌리지 않는다")
    func filterPinsLoadFailed_ignoresStaleFailure() async {
        let store = makeStore(
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .nearby, pins: [], isDeckLoading: true
            )
        )
        await store.send(.filterPinsLoadFailed(for: .latest, revertTo: .recommended, index: 0))
        #expect(store.currentState.selectedFilter == .nearby)
        #expect(store.currentState.isDeckLoading)
        store.finish()
    }

    @Test("L1 — 같은 기준을 다시 고르면 아무 일도 하지 않는다(불필요한 재조회 방지)")
    func selectFilter_ignoresSameFilter() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, selectedFilter: .latest))
        await store.send(.selectFilter(.latest))
        store.finish()
    }

    @Test("L2 — 한 기준의 덱을 다 넘기면 다음 기준으로 자동 전환하고 새 덱을 받는다")
    func swipeForward_advancesToNextFilter() async {
        let nextDeck = multiRoomPins()
        let store = makeStore(
            fetchPins: StubFetchPins(all: nextDeck),
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .recommended,
                pins: fixturePins, currentCardIndex: fixturePins.count - 1
            )
        )
        await store.send(.swipeForward) {
            $0.currentCardIndex = fixturePins.count   // 덱 밖
            $0.selectedFilter = .latest               // 꾹 Pick → 최신순
            $0.isDeckLoading = true
        }
        await store.receive(.filterPinsLoaded(pins: nextDeck, entry: .first, for: .latest)) {
            $0.isDeckLoading = false
            $0.pins = nextDeck
            $0.currentCardIndex = 0
        }
        #expect(!store.currentState.hasViewedAllPlaces)
        store.finish()
    }

    @Test("L2 — 소진 자동 전환이 실패하면 덱 밖 인덱스를 마지막 카드로 되돌린다")
    func swipeForward_revertsOnFetchFailure() async {
        let store = makeStore(
            fetchPins: ThrowingFetchPins(),
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .recommended,
                pins: fixturePins, currentCardIndex: fixturePins.count - 1
            )
        )
        await store.send(.swipeForward) {
            $0.currentCardIndex = fixturePins.count   // 덱 밖
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        // 전환 직전 인덱스가 덱 밖이라, 되돌릴 때 마지막 카드로 클램프된다
        await store.receive(.filterPinsLoadFailed(for: .latest, revertTo: .recommended, index: fixturePins.count)) {
            $0.isDeckLoading = false
            $0.selectedFilter = .recommended
            $0.currentCardIndex = fixturePins.count - 1
        }
        #expect(!store.currentState.isCurrentDeckExhausted)   // 다시 넘기면 재시도된다
        store.finish()
    }

    @Test("L1 — 마지막 기준(가까운순)까지 소진하면 전환 없이 소진 화면으로 간다")
    func swipeForward_stopsAtLastFilter() async {
        let store = makeStore(
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .nearby,
                pins: fixturePins, currentCardIndex: fixturePins.count - 1
            )
        )
        await store.send(.swipeForward) { $0.currentCardIndex = fixturePins.count }
        #expect(store.currentState.hasViewedAllPlaces)   // 002-3 소진 화면
        #expect(store.currentState.selectedFilter == .nearby)
        store.finish()
    }

    @Test("PinFilter.next 는 칩 순서를 따르고 마지막에서 끝난다")
    func pinFilterNext_followsChipOrder() {
        #expect(PinFilter.recommended.next == .latest)
        #expect(PinFilter.latest.next == .nearby)
        #expect(PinFilter.nearby.next == nil)
    }

    // MARK: - Navigation

    @Test("tapCreateRoom 은 goToCreateRoom 으로 navigate 한다")
    func tapCreateRoom_navigates() async {
        let store = makeStore()
        await store.send(.tapCreateRoom)
        store.receiveNavigation(.goToCreateRoom)
        store.finish()
    }

    // MARK: - Card Deck

    @Test("L1 — pinsLoaded 는 pins·인덱스를 세팅하고 로딩을 끝낸다 (최초 실행 = 첫 방부터)")
    func pinsLoaded() async {
        let store = makeStore(state: HomeState(isLoading: true, currentCardIndex: 5))
        await store.send(.pinsLoaded(pins: fixturePins, startRoomID: nil)) {
            $0.pins = fixturePins
            $0.currentCardIndex = 0
            $0.isLoading = false   // 핀 도착 시점에 로딩 종료(빈 상태 깜빡임 방지)
        }
        store.finish()
    }

    // MARK: - 홈 사용 가이드 (정책 1)

    @Test("L2 — 최초 진입(가이드 미표기 + 카드 있음)이면 가이드를 띄우고 그 시점에 1회 표기를 기록한다")
    func guide_showsOnceOnFirstEntry() async {
        let guide = SpyHomeGuide(seen: false)
        let store = makeStore(homeGuide: guide, state: HomeState(isLoading: true))
        await store.send(.pinsLoaded(pins: fixturePins, startRoomID: nil)) {
            $0.pins = fixturePins
            $0.currentCardIndex = 0
            $0.isLoading = false
        }
        await store.receive(.showGuide) { $0.isGuidePresented = true }
        #expect(await guide.markedSeen == 1)
        store.finish()
    }

    @Test("L2 — 이미 본 가이드는 다시 띄우지 않는다")
    func guide_doesNotShowWhenSeen() async {
        let store = makeStore(homeGuide: SpyHomeGuide(seen: true), state: HomeState(isLoading: true))
        await store.send(.pinsLoaded(pins: fixturePins, startRoomID: nil)) {
            $0.pins = fixturePins
            $0.currentCardIndex = 0
            $0.isLoading = false
        }
        store.finish()   // showGuide 미수신 — 잔여 effect 없음
    }

    @Test("L2 — 카드가 0장이면(빈 상태) 스와이프 가이드를 띄우지 않는다")
    func guide_doesNotShowWithoutCards() async {
        let store = makeStore(homeGuide: SpyHomeGuide(seen: false), state: HomeState(isLoading: true))
        await store.send(.pinsLoaded(pins: [], startRoomID: nil)) { $0.isLoading = false }
        store.finish()
    }

    @Test("L1 — dismissGuide 는 가이드를 닫는다 (X 버튼)")
    func guide_dismisses() async {
        let store = makeStore(state: HomeState(isGuidePresented: true))
        await store.send(.dismissGuide) { $0.isGuidePresented = false }
        store.finish()
    }

    // MARK: - 재실행 시 이어 보기 (정책 3)

    @Test("L1 — pinsLoaded 는 마지막으로 본 방이 있으면 그 방 첫 카드부터 시작한다")
    func pinsLoaded_startsAtLastViewedRoom() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isLoading: true))
        await store.send(.pinsLoaded(pins: multiRoomPins(), startRoomID: "2")) {
            $0.pins = multiRoomPins()
            $0.currentCardIndex = 3     // 방2 구간 시작
            $0.selectedRoomID = "2"
            $0.isLoading = false
        }
        #expect(store.currentState.currentRoom?.id == "2")
        store.finish()
    }

    @Test("L1 — 마지막으로 본 방에 카드가 없으면(삭제·스루) 첫 방부터 시작한다")
    func pinsLoaded_fallsBackWhenLastRoomHasNoCards() async {
        // 시작 인덱스를 0 이 아닌 값으로 둔다 — 기대값 0 이 초기값과 같으면
        // 폴백이 동작한 건지 아무 일도 안 일어난 건지 구분되지 않는다.
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isLoading: true, currentCardIndex: 3))
        await store.send(.pinsLoaded(pins: multiRoomPins(), startRoomID: "없는-방")) {
            $0.pins = multiRoomPins()
            $0.currentCardIndex = 0     // 3 → 0 으로 되돌린다. selectedRoomID 도 그대로 nil
            $0.isLoading = false
        }
        store.finish()
    }

    @Test("L2 — load 는 마지막으로 본 방을 함께 읽어 pinsLoaded 에 실어 보낸다")
    func load_carriesLastViewedRoom() async {
        let pins = multiRoomPins()
        let store = makeStore(
            fetchPins: StubFetchPins(all: pins),
            lastViewedRoom: SpyLastViewedRoom(stored: "2"),
            state: HomeState()
        )
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixtureRooms)) { $0.rooms = fixtureRooms }
        await store.receive(.pinsLoaded(pins: pins, startRoomID: "2")) {
            $0.pins = pins
            $0.currentCardIndex = 3
            $0.selectedRoomID = "2"
            $0.isLoading = false
        }
        store.finish()
    }

    @Test("L2 — 방이 바뀔 때만 마지막으로 본 방을 기록한다 (같은 방 안 이동은 기록 안 함)")
    func persistsLastViewedRoomOnlyOnRoomChange() async {
        let spy = SpyLastViewedRoom()
        // 방1(0,1,2) + 방2(3,4), 방1 첫 카드에서 시작
        let store = makeStore(
            lastViewedRoom: spy,
            state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 0)
        )
        await store.send(.swipeForward) { $0.currentCardIndex = 1 }   // 방1 안 이동
        #expect(await spy.saved.isEmpty)

        await store.send(.swipeForward) { $0.currentCardIndex = 2 }
        await store.send(.swipeForward) { $0.currentCardIndex = 3 }   // 방2 진입
        #expect(await spy.saved == ["2"])

        await store.send(.swipeBackward) { $0.currentCardIndex = 2 }  // 방1 복귀
        #expect(await spy.saved == ["2", "1"])
        store.finish()
    }

    @Test("L2 — 방 리스트에서 방을 고르면 그 방을 마지막으로 본 방으로 기록한다")
    func persistsLastViewedRoomOnSelect() async {
        let spy = SpyLastViewedRoom()
        let store = makeStore(
            lastViewedRoom: spy,
            state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), isRoomListPresented: true)
        )
        await store.send(.selectRoom("2")) {
            $0.currentCardIndex = 3
            $0.isRoomListPresented = false
            $0.selectedRoomID = "2"
            $0.changedRoomToastID = "2"
        }
        #expect(await spy.saved == ["2"])
        store.finish()
    }

    @Test("L1 — swipeForward 는 인덱스를 1 증가시킨다")
    func swipeForward() async {
        let store = makeStore(state: HomeState(pins: fixturePins, currentCardIndex: 0))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
        }
        store.finish()
    }

    @Test("L1 — swipeForward 는 마지막 카드에서 한 번 더 넘어가 덱 밖(소진)으로 나가고, 그 뒤로 clamp 된다")
    func swipeForward_exitsDeckThenClamps() async {
        // 마지막 기준(가까운순)이라 다음 기준으로의 자동 전환은 일어나지 않는다 — 인덱스만 검증
        let store = makeStore(state: HomeState(selectedFilter: .nearby, pins: fixturePins, currentCardIndex: 2))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 3   // = pins.count → 소진 상태(002-3)
        }
        #expect(store.currentState.hasViewedAllPlaces)
        await store.send(.swipeForward)   // 덱 밖에서는 더 이상 전진하지 않음
        store.finish()
    }

    @Test("L1 — swipeBackward 는 인덱스를 1 감소시킨다")
    func swipeBackward() async {
        let store = makeStore(state: HomeState(pins: fixturePins, currentCardIndex: 2))
        await store.send(.swipeBackward) {
            $0.currentCardIndex = 1
        }
        store.finish()
    }

    @Test("L1 — swipeBackward 는 첫 카드에서 clamp 된다")
    func swipeBackward_clamps() async {
        let store = makeStore(state: HomeState(pins: fixturePins, currentCardIndex: 0))
        await store.send(.swipeBackward)
        store.finish()
    }

    @Test("L1 — tapCard 는 상태를 변경하지 않는다")
    func tapCard_noop() async {
        let store = makeStore(state: HomeState(pins: fixturePins))
        await store.send(.tapCard(PinID("pin-0")))
        store.finish()
    }

    @Test("L2 — tapMorePlaces 는 page 를 올려 fetchPins 를 호출하고, 결과로 현재 방 구간을 교체하며 인덱스를 리셋한다")
    func tapMorePlaces_regenerates() async {
        let morePins = (0..<10).map { i in
            Pin(id: PinID("more-1-\(i)"), roomID: "1", category: .savedByMany,
                title: "새 장소 \(i)", address: "주소", createdAt: fixtureDate)
        }
        let store = makeStore(
            fetchPins: StubFetchPins(more: morePins),
            state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2)
        )
        // send: page 커서만 오른다(데이터 교체는 morePlacesLoaded 응답에서)
        await store.send(.tapMorePlaces) { $0.roomPages["1"] = 1 }
        // receive: 방1 구간(fixturePins 3장 전부) → 새 10장으로 교체, 인덱스 0
        await store.receive(.morePlacesLoaded(roomID: "1", pins: morePins)) {
            $0.pins = morePins
            $0.currentCardIndex = 0
        }
        store.finish()
    }

    // MARK: - 다중 방 진행

    /// 방1(3장) + 방2(2장) 을 방 순서대로 이어붙인 평면 덱.
    private func multiRoomPins() -> [Pin] {
        let r1 = (0..<3).map { i in
            Pin(id: PinID("a-\(i)"), roomID: "1", category: .savedByMany,
                title: "A\(i)", address: "주소", createdAt: fixtureDate)
        }
        let r2 = (0..<2).map { i in
            Pin(id: PinID("b-\(i)"), roomID: "2", category: .savedByMany,
                title: "B\(i)", address: "주소", createdAt: fixtureDate)
        }
        return r1 + r2
    }

    @Test("currentRoom 은 현재 맨 앞 카드가 속한 방을 반영한다")
    func currentRoom_followsCard() {
        var state = HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 0)
        #expect(state.currentRoom?.id == "1")
        state.currentCardIndex = 4
        #expect(state.currentRoom?.id == "2")
    }

    @Test("remainingInCurrentRoom 은 덱 전체가 아니라 현재 방 구간의 남은 카드를 센다")
    func remainingInCurrentRoom_countsWithinRoom() {
        // 방1: index 0,1,2 / 방2: index 3,4
        var state = HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 0)
        #expect(state.remainingInCurrentRoom == 3)   // 방1 3장 남음
        state.currentCardIndex = 2
        #expect(state.remainingInCurrentRoom == 1)   // 방1 마지막 카드
        state.currentCardIndex = 3
        #expect(state.remainingInCurrentRoom == 2)   // 방2 진입, 2장 남음
    }

    @Test("L1 — swipeForward 는 방 경계를 넘어 다음 방 첫 카드로 이어진다")
    func swipeForward_crossesRoomBoundary() async {
        // index 2 = 방1 마지막 카드
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 2))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 3   // 방2 첫 카드
        }
        #expect(store.currentState.currentRoom?.id == "2")
        store.finish()
    }

    @Test("L1 — 마지막 방 마지막 카드에서 swipeForward 는 전 방 소진 상태로 나간다")
    func swipeForward_entersAllViewedAtVeryLastCard() async {
        // index 4 = 방2(마지막 방) 마지막 카드. 마지막 기준이라 필터 자동 전환은 없다.
        let store = makeStore(
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .nearby,
                pins: multiRoomPins(), currentCardIndex: 4
            )
        )
        await store.send(.swipeForward) {
            $0.currentCardIndex = 5   // = pins.count
        }
        #expect(store.currentState.hasViewedAllPlaces)
        // 뱃지는 첫 방으로 튀지 않고 마지막으로 본 방(방2)을 유지한다
        #expect(store.currentState.currentRoom?.id == "2")
        store.finish()
    }

    // MARK: - 전 방 소진 (002-3 「모든 카드를 다 봤을 때」)

    @Test("소진 화면은 마지막 기준(가까운순)의 덱까지 다 넘겼을 때만 뜬다")
    func hasViewedAllPlaces_onlyOnLastFilter() {
        // 중간 기준(꾹 Pick)은 덱을 다 넘겨도 소진 화면이 아니라 다음 기준으로 넘어갈 자리다
        var middle = HomeState(rooms: fixtureRooms, selectedFilter: .recommended, pins: multiRoomPins())
        middle.currentCardIndex = 5
        #expect(middle.isCurrentDeckExhausted)
        #expect(!middle.hasViewedAllPlaces)

        var last = HomeState(rooms: fixtureRooms, selectedFilter: .nearby, pins: multiRoomPins(), currentCardIndex: 4)
        #expect(!last.hasViewedAllPlaces)       // 마지막 카드를 보는 중
        last.currentCardIndex = 5
        #expect(last.hasViewedAllPlaces)        // 마지막 기준의 덱 밖으로 나감
        #expect(!last.showsEmptyState)          // 빈 상태(카드 0장)와는 다른 화면

        let noPins = HomeState(rooms: fixtureRooms, selectedFilter: .nearby, pins: [], currentCardIndex: 0)
        #expect(!noPins.hasViewedAllPlaces)     // 애초에 볼 장소가 없으면 소진이 아니라 빈 상태
    }

    @Test("L2 — tapMorePlaces 는 현재 방(방2) 구간만 교체하고 방1 은 그대로 두며 그 방 첫 카드로 리셋한다")
    func tapMorePlaces_replacesOnlyCurrentRoomSlice() async {
        let base = multiRoomPins()   // 방1 3장(index 0..2) + 방2 2장(3..4)
        let morePins = (0..<10).map { i in
            Pin(id: PinID("more-2-\(i)"), roomID: "2", category: .savedByMany,
                title: "새 장소 \(i)", address: "주소", createdAt: fixtureDate)
        }
        // index 4 = 방2 카드 → 방2 구간만 교체
        let store = makeStore(
            fetchPins: StubFetchPins(more: morePins),
            state: HomeState(rooms: fixtureRooms, pins: base, currentCardIndex: 4)
        )
        await store.send(.tapMorePlaces) { $0.roomPages["2"] = 1 }
        await store.receive(.morePlacesLoaded(roomID: "2", pins: morePins)) {
            $0.pins = Array(base.prefix(3)) + morePins   // 방1 3장 유지 + 방2 새 10장
            $0.currentCardIndex = 3                       // 방2 구간 시작
        }
        #expect(store.currentState.roomPages["1"] == nil)   // 방1 page 는 건드리지 않음
        #expect(store.currentState.currentRoom?.id == "2")
        store.finish()
    }

    @Test("L1 — morePlacesLoaded 가 빈 결과면 덱을 지우지 않는다(페이지 소진 방어)")
    func morePlacesLoaded_emptyKeepsDeck() async {
        // 실 API 가 "더 이상 없음"으로 [] 를 주면 그 방 구간이 통째로 사라지던 회귀 방어.
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2))
        await store.send(.morePlacesLoaded(roomID: "1", pins: []))   // 변화 없음
        store.finish()
        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.currentCardIndex == 2)
    }

    @Test("L2 — tapMorePlaces 는 핀 조회 실패 시 덱을 훼손하지 않는다(기존 카드 유지)")
    func tapMorePlaces_failureKeepsDeck() async {
        let store = makeStore(
            fetchPins: ThrowingFetchPins(),
            state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2)
        )
        // send: page 커서는 전진한다(현재 동작 — 실패 롤백은 tapMorePlaces 의 FIXME 참조)
        await store.send(.tapMorePlaces) { $0.roomPages["1"] = 1 }
        // 실패는 조용히 무시 → morePlacesLoaded 미도착, pins·인덱스 그대로
        store.finish()
        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.currentCardIndex == 2)
    }

    // MARK: - 방 선택 바텀 시트

    @Test("L1 — tapRoomBadge 는 방 선택 시트를 연다")
    func tapRoomBadge_presents() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms))
        await store.send(.tapRoomBadge) { $0.isRoomListPresented = true }
        store.finish()
    }

    @Test("L1 — 시트가 열린 상태의 tapRoomBadge(마스코트 재탭) 는 시트를 닫는다")
    func tapRoomBadge_whilePresented_dismisses() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isRoomListPresented: true))
        await store.send(.tapRoomBadge) { $0.isRoomListPresented = false }
        store.finish()
    }

    @Test("L1 — dismissRoomList 는 시트를 닫는다")
    func dismissRoomList_dismisses() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isRoomListPresented: true))
        await store.send(.dismissRoomList) { $0.isRoomListPresented = false }
        store.finish()
    }

    @Test("L2 — selectRoom 은 해당 방 첫 카드로 전환하고 시트를 닫으며 변경 툴팁을 세운다")
    func selectRoom_switchesAndToasts() async {
        // 방1(index 0,1,2) + 방2(3,4), 현재 방1의 두 번째 카드
        let store = makeStore(
            state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 1, isRoomListPresented: true)
        )
        await store.send(.selectRoom("2")) {
            $0.currentCardIndex = 3                 // 방2 구간 시작
            $0.isRoomListPresented = false
            $0.selectedRoomID = "2"
            $0.changedRoomToastID = "2"             // 식별은 id — 툴팁 표기("데이트 코스방이에요")는 뷰가 이 id 로 파생
        }
        store.finish()
    }

    @Test("L2 — 카드가 없어도(빈 방) selectRoom 이 현재 방을 바꾼다 (뱃지·방리스트 선택 반영)")
    func selectRoom_withNoPins_updatesCurrentRoom() async {
        // 모든 방이 비어 pins 가 없는 상태 — 예전엔 currentRoom 이 항상 첫 방(내 장소)에 고정됐다.
        let store = makeStore(
            state: HomeState(rooms: fixtureRooms, pins: [], isRoomListPresented: true)
        )
        #expect(store.currentState.currentRoom?.id == fixtureRooms.first?.id)   // 선택 전: 첫 방
        await store.send(.selectRoom("2")) {
            $0.isRoomListPresented = false
            $0.selectedRoomID = "2"                 // 카드가 없어 currentCardIndex 는 그대로
            $0.changedRoomToastID = "2"
        }
        #expect(store.currentState.currentRoom?.id == "2")   // 선택 후: 고른 방이 현재 방
        store.finish()
    }

    @Test("L1 — dismissRoomToast 는 같은 방(id 일치) 툴팁을 숨긴다")
    func dismissRoomToast_hides() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, changedRoomToastID: "1"))
        await store.send(.dismissRoomToast("1")) { $0.changedRoomToastID = nil }
        store.finish()
    }

    @Test("L1 — dismissRoomToast 는 다른 방(id 불일치)으로 바뀌었으면 툴팁을 지우지 않는다")
    func dismissRoomToast_ignoresStaleID() async {
        // 방을 바꿔 툴팁이 방2 를 가리키는데, 이전 방(방1) 타이머의 dismiss 가 뒤늦게 도착한 상황
        let store = makeStore(state: HomeState(rooms: fixtureRooms, changedRoomToastID: "2"))
        await store.send(.dismissRoomToast("1"))   // 상태 변화 없음 — 새 방 툴팁 유지
        store.finish()
    }

    @Test("L1 — 이름이 같은 방들도 id 로 구분해 stale 타이머가 남의 툴팁을 지우지 않는다")
    func dismissRoomToast_distinguishesSameNamedRoomsByID() async {
        // 같은 이름("모임")의 서로 다른 방 두 개 — 이름 기반이었다면 stale dismiss 가 오작동했을 케이스.
        let sameName = [
            Room(id: "a", type: .shared, name: "모임", description: nil,
                 color: "#FF6B6B", ownerId: "o", inviteCode: "A",
                 createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []),
            Room(id: "b", type: .shared, name: "모임", description: nil,
                 color: "#4ECDC4", ownerId: "o", inviteCode: "B",
                 createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []),
        ]
        // 현재 툴팁은 방 "b" 를 가리킴. 이전 방 "a" 타이머의 뒤늦은 dismiss 가 도착.
        let store = makeStore(state: HomeState(rooms: sameName, changedRoomToastID: "b"))
        await store.send(.dismissRoomToast("a"))   // 이름은 같지만 id 가 달라 무시(이름 기반이면 잘못 지웠을 것)
        #expect(store.currentState.changedRoomToastID == "b")
        await store.send(.dismissRoomToast("b")) { $0.changedRoomToastID = nil }   // 같은 id 는 정상 숨김
        store.finish()
    }

    @Test("L1 — tapCreateRoom 은 시트를 닫고 goToCreateRoom 으로 navigate 한다")
    func tapCreateRoom_dismissesAndNavigates() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isRoomListPresented: true))
        await store.send(.tapCreateRoom) { $0.isRoomListPresented = false }
        store.receiveNavigation(.goToCreateRoom)
        store.finish()
    }

    // MARK: - 게시물 저장 시트 (Figma 013-1-3 / 013-2)

    /// 시트를 연 상태 — 카드 `pin-0`(방 "1" 소속)의 저장 시트.
    private var openedSavePostState: HomeState {
        HomeState(
            rooms: fixtureRooms,
            pins: fixturePins,
            savePost: SavePostState(pinID: PinID("pin-0"), alreadySavedRoomIDs: ["1"])
        )
    }

    @Test("L1 — tapSaveToOtherRoom 은 카드가 속한 방을 '이미 저장된 방'으로 두고 시트를 연다")
    func tapSaveToOtherRoom_opensSheetWithCurrentRoomChecked() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins))
        await store.send(.tapSaveToOtherRoom(PinID("pin-0"))) {
            $0.savePost = SavePostState(pinID: PinID("pin-0"), alreadySavedRoomIDs: ["1"])
        }
        // 중복 저장 방지: 그 방은 체크로 보이되 저장 대상(selected)에는 안 들어간다.
        #expect(store.currentState.savePost?.checkedRoomIDs == ["1"])
        #expect(store.currentState.savePost?.canSubmit == false)
        store.finish()
    }

    @Test("L1 — 덱에 없는 카드로 열면 이미 저장된 방 없이 시트만 연다")
    func tapSaveToOtherRoom_unknownPinHasNoSavedRoom() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins))
        await store.send(.tapSaveToOtherRoom(PinID("없는-핀"))) {
            $0.savePost = SavePostState(pinID: PinID("없는-핀"))
        }
        store.finish()
    }

    @Test("L1 — toggleSavePostRoom 은 선택을 켜고 끄며, 켜지면 저장 버튼이 열린다")
    func toggleSavePostRoom_togglesSelection() async {
        let store = makeStore(state: openedSavePostState)
        await store.send(.toggleSavePostRoom("2")) { $0.savePost?.selectedRoomIDs = ["2"] }
        #expect(store.currentState.savePost?.canSubmit == true)
        #expect(store.currentState.savePost?.checkedRoomIDs == ["1", "2"])
        await store.send(.toggleSavePostRoom("2")) { $0.savePost?.selectedRoomIDs = [] }
        #expect(store.currentState.savePost?.canSubmit == false)
        store.finish()
    }

    @Test("L1 — 이미 저장된 방은 토글되지 않는다(중복 저장 차단)")
    func toggleSavePostRoom_ignoresAlreadySavedRoom() async {
        let store = makeStore(state: openedSavePostState)
        await store.send(.toggleSavePostRoom("1"))   // 변화 없음
        #expect(store.currentState.savePost?.selectedRoomIDs.isEmpty == true)
        store.finish()
    }

    @Test("L1 — 저장 중에는 선택을 바꿀 수 없다(화면과 실제 저장 대상이 어긋나지 않게)")
    func toggleSavePostRoom_ignoredWhileSaving() async {
        var state = openedSavePostState
        state.savePost?.selectedRoomIDs = ["2"]
        state.savePost?.isSaving = true
        let store = makeStore(state: state)
        await store.send(.toggleSavePostRoom("2"))   // 변화 없음
        #expect(store.currentState.savePost?.selectedRoomIDs == ["2"])
        store.finish()
    }

    @Test("L2 — tapSavePost 는 고른 방으로 저장하고, 끝나면 시트를 닫고 완료 토스트를 띄운다")
    func tapSavePost_savesThenShowsToast() async {
        let spy = SpySavePin()
        var state = openedSavePostState
        state.savePost?.selectedRoomIDs = ["2"]
        let store = makeStore(savePin: spy, state: state)

        await store.send(.tapSavePost) { $0.savePost?.isSaving = true }
        await store.receive(.savePostFinished) {
            $0.savePost = nil
            $0.savedToastID = 1
        }
        store.finish()

        let saved = await spy.saved
        #expect(saved.count == 1)
        #expect(saved.first?.pinID == PinID("pin-0"))
        #expect(saved.first?.roomIDs == ["2"])   // 이미 저장된 방("1")은 안 보낸다
    }

    @Test("L1 — 고른 방이 없으면 tapSavePost 는 아무것도 하지 않는다")
    func tapSavePost_ignoredWithoutSelection() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: openedSavePostState)
        await store.send(.tapSavePost)   // 변화 없음
        store.finish()
        #expect(await spy.saved.isEmpty)
    }

    @Test("L1 — 저장 중 저장하기를 다시 눌러도 저장이 두 번 나가지 않는다")
    func tapSavePost_ignoredWhileSaving() async {
        let spy = SpySavePin()
        var state = openedSavePostState
        state.savePost?.selectedRoomIDs = ["2"]
        state.savePost?.isSaving = true
        let store = makeStore(savePin: spy, state: state)
        await store.send(.tapSavePost)   // 변화 없음 — effect 도 나가지 않는다(finish 가 검사)
        store.finish()
        #expect(await spy.saved.isEmpty)
    }

    @Test("L2 — 저장이 실패하면 시트를 저장 전 상태로 되돌려 다시 시도할 수 있다")
    func tapSavePost_failureRestoresSheet() async {
        var state = openedSavePostState
        state.savePost?.selectedRoomIDs = ["2"]
        let store = makeStore(savePin: ThrowingSavePin(), state: state)

        await store.send(.tapSavePost) { $0.savePost?.isSaving = true }
        await store.receive(.savePostFailed) { $0.savePost?.isSaving = false }
        // 시트가 살아 있고 선택도 그대로라 그대로 재시도된다.
        #expect(store.currentState.savePost?.selectedRoomIDs == ["2"])
        #expect(store.currentState.savedToastID == nil)   // 실패는 완료 토스트를 띄우지 않는다
        store.finish()
    }

    @Test("L2 — 저장 중 시트를 닫아도 저장은 끝까지 진행돼 완료 토스트가 뜬다")
    func dismissSavePost_whileSavingStillCompletes() async {
        let spy = SpySavePin()
        var state = openedSavePostState
        state.savePost?.selectedRoomIDs = ["2"]
        let store = makeStore(savePin: spy, state: state)

        await store.send(.tapSavePost) { $0.savePost?.isSaving = true }
        // 저장이 도는 사이 스와이프로 시트를 닫는다.
        await store.send(.dismissSavePost) { $0.savePost = nil }
        // 진행 중이던 저장은 잘리지 않고 끝나 토스트로 이어진다 — 시트가 없어도 토스트는 뜬다.
        await store.receive(.savePostFinished) { $0.savedToastID = 1 }
        store.finish()

        #expect(await spy.saved.count == 1)   // 닫혔다고 저장이 취소되지 않는다
    }

    @Test("L1 — 연속 저장은 토스트 id 를 올려 자동 dismiss 타이머를 다시 시작시킨다")
    func savePostFinished_incrementsToastID() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, savedToastID: 1))
        await store.send(.savePostFinished) { $0.savedToastID = 2 }
        store.finish()
    }

    @Test("L1 — dismissSavedToast 는 같은 id 일 때만 토스트를 지운다")
    func dismissSavedToast_ignoresStaleID() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, savedToastID: 2))
        await store.send(.dismissSavedToast(1))   // 이전 타이머의 뒤늦은 dismiss — 무시
        #expect(store.currentState.savedToastID == 2)
        await store.send(.dismissSavedToast(2)) { $0.savedToastID = nil }
        store.finish()
    }

    // MARK: - 방 이름 표기

    @Test("공동방은 표기 이름에 '방'을 붙이고, 개인방은 이름과 무관하게 '내 장소'로 표기한다")
    func homeDisplayName_suffixByType() {
        // 서버가 개인방에 다른 이름을 줘도 홈 표기는 "내 장소" 로 고정된다
        #expect(fixtureRooms[0].homeDisplayName == "맛집 탐방방")            // 공동방
        #expect(personalRoom(name: "내 장소").homeDisplayName == "내 장소")
        #expect(personalRoom(name: "나의 아지트").homeDisplayName == "내 장소")
    }

    @Test("툴팁 문구는 공동방 '…방이에요.', 개인방 '내 장소예요.'")
    func homeToastText_byType() {
        #expect(fixtureRooms[0].homeToastText == "맛집 탐방방이에요.")        // 공동방 — 받침 있어 "이에요"
        #expect(personalRoom(name: "나의 아지트").homeToastText == "내 장소예요.")   // 개인방 — 받침 없어 "예요"
    }

    private func personalRoom(name: String) -> Room {
        Room(
            id: "0", type: .personal, name: name, description: nil,
            color: "#00BDDE", ownerId: "owner-1", inviteCode: "MYROOM",
            createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
        )
    }
}
