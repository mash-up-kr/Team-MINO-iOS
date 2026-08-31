import Foundation
import Domain
import MVITestSupport
import Testing
@testable import FeatureHome

private let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)

private let fixtureRooms = [
    Room(
        id: "1", type: .shared, name: "맛집 탐방", description: nil,
        color: nil, ownerId: "owner-1", createdAt: fixtureDate, pinCount: 3, memberCount: 2, users: []
    ),
    Room(
        id: "2", type: .shared, name: "데이트 코스", description: nil,
        color: nil, ownerId: "owner-1", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
    ),
]

private let fixturePins: [Pin] = (0..<3).map { i in
    PinFixture.pin(
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

/// 방·정렬과 무관하게 같은 덱을 돌려주는 스텁(로드 흐름 테스트용).
private struct StubFetchPins: FetchHomeCardsUseCase {
    var all: [Pin] = []
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] { all }
}

/// 스텁이 돌려주는 좌표. 가까운순 흐름의 단언이 이 값을 그대로 쓴다.
private let stubCoordinate = Coordinate(latitude: 37.5, longitude: 127.0)

/// 좌표를 돌려주는 스텁 — 가까운순 덱은 좌표를 얻어야 조회로 넘어간다.
private struct StubCurrentLocation: CurrentLocationUseCase {
    var result: CurrentLocationResult = .coordinate(stubCoordinate)
    func execute() async -> CurrentLocationResult { result }
}

/// (방 × 정렬)별 덱을 돌려주는 스텁 — 홈이 방 단위로 조회하므로 그 키로 찾는다.
/// `failing` 에 담은 키는 조회가 실패한다(복구 경로 검증용).
private struct StubRoomDecks: FetchHomeCardsUseCase {
    var decks: [String: [Pin]] = [:]
    var failing: Set<String> = []
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] {
        let key = deckKey(room.id, filter)
        if failing.contains(key) { throw DomainError.unknown }
        return decks[key] ?? []
    }
}

private func deckKey(_ roomID: String, _ filter: PinFilter) -> String { "\(roomID)/\(filter.rawValue)" }

/// 한 (방 × 정렬) 덱. `tag` 로 어느 덱인지 구분한다.
private func deckPins(_ tag: String, room: String, count: Int) -> [Pin] {
    (0..<count).map { i in
        PinFixture.pin(id: PinID("\(tag)-\(i)"), roomID: room, category: .savedByMany,
                       title: "\(tag)\(i)", address: "주소", createdAt: fixtureDate)
    }
}

/// 「경과일 초기화 확인」 스파이 — 어느 장소로 몇 번 나갔는지 센다.
private actor SpyRecordPinAccess: RecordPinAccessUseCase {
    private(set) var recorded: [PinID] = []
    func execute(pinID: PinID) async throws { recorded.append(pinID) }
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
private struct ThrowingFetchPins: FetchHomeCardsUseCase {
    var error: DomainError = .unknown
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] { throw error }
}

/// 아바타 색을 고정으로 돌려주는 스텁 — 마스코트 색 흐름을 검증한다.
private struct StubFetchProfile: FetchProfileUseCase {
    var color: AvatarColor? = .cyan
    func execute() async throws -> Profile {
        Profile(id: "me", nickname: "나", avatarColor: color, createdAt: nil)
    }
}

/// 프로필 조회가 항상 실패하는 스텁 — 마스코트가 기본으로 떨어지는 경로를 검증한다.
private struct ThrowingFetchProfile: FetchProfileUseCase {
    func execute() async throws -> Profile { throw DomainError.unknown }
}

@MainActor
struct HomeReducerTests {
    private func makeStore(
        _ fetchRooms: FetchRoomsUseCase = StubFetchRooms(),
        fetchPins: FetchHomeCardsUseCase = StubFetchPins(),
        currentLocation: CurrentLocationUseCase = StubCurrentLocation(),
        lastViewedRoom: LastViewedRoomUseCase = SpyLastViewedRoom(),
        homeGuide: HomeGuideUseCase = SpyHomeGuide(seen: true),   // 기본은 "이미 본" — 가이드 없는 흐름
        savePin: SavePinToRoomsUseCase = SpySavePin(),
        fetchProfile: FetchProfileUseCase = StubFetchProfile(),
        recordPinAccess: RecordPinAccessUseCase = SpyRecordPinAccess(),
        state: HomeState = HomeState()
    ) -> TestStore<HomeState, HomeAction, HomeNav> {
        TestStore(
            state,
            reduce: homeReducer(
                fetchRooms: fetchRooms,
                fetchHomeCards: fetchPins,
                currentLocation: currentLocation,
                lastViewedRoom: lastViewedRoom,
                homeGuide: homeGuide,
                savePin: savePin,
                fetchProfile: fetchProfile,
                recordPinAccess: recordPinAccess
            )
        )
    }

    // MARK: - 마스코트 아바타 색

    @Test("L2 — loadMyAvatar 는 프로필 색을 상태에 싣는다")
    func loadMyAvatar_success() async {
        let store = makeStore(fetchProfile: StubFetchProfile(color: .violet))
        await store.send(.loadMyAvatar)
        await store.receive(.myAvatarLoaded(.violet)) { $0.myAvatarColor = .violet }
        store.finish()
    }

    @Test("L2 — 프로필 조회가 실패해도 화면을 막지 않고 색만 비운다")
    func loadMyAvatar_failure() async {
        let store = makeStore(fetchProfile: ThrowingFetchProfile(), state: HomeState(myAvatarColor: .red))
        await store.send(.loadMyAvatar)
        await store.receive(.myAvatarLoaded(nil)) { $0.myAvatarColor = nil }
        #expect(store.currentState.errorMessage == nil)
        store.finish()
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
            color: nil, ownerId: "owner-1", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
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
            color: nil, ownerId: "o", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
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

    @Test("L1 — 같은 기준을 다시 고르면 아무 일도 하지 않는다(불필요한 재조회 방지)")
    func selectFilter_ignoresSameFilter() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, selectedFilter: .latest))
        await store.send(.selectFilter(.latest))
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

    // MARK: - 홈 사용 가이드 (정책 1)

    @Test("L2 — 최초 진입(가이드 미표기)이면 가이드를 띄우고 그 시점에 1회 표기를 기록한다")
    func guide_showsOnceOnFirstEntry() async {
        let guide = SpyHomeGuide(seen: false)
        let store = makeStore(homeGuide: guide, state: HomeState(rooms: fixtureRooms, isLoading: true))
        await store.send(.checkGuide)
        await store.receive(.showGuide) { $0.isGuidePresented = true }
        #expect(await guide.markedSeen == 1)
        store.finish()
    }

    @Test("L2 — 이미 본 가이드는 다시 띄우지 않는다")
    func guide_doesNotShowWhenSeen() async {
        let store = makeStore(homeGuide: SpyHomeGuide(seen: true), state: HomeState(rooms: fixtureRooms, isLoading: true))
        await store.send(.checkGuide)
        store.finish()   // showGuide 미수신 — 잔여 effect 없음
    }

    @Test("L2 — 카드가 0장이어도 가이드를 띄운다 (가이드가 가리키는 덱은 모형이라 실 데이터와 무관)")
    func guide_showsWithoutCards() async {
        let store = makeStore(homeGuide: SpyHomeGuide(seen: false), state: HomeState())
        await store.send(.checkGuide)
        await store.receive(.showGuide) { $0.isGuidePresented = true }
        store.finish()
    }

    @Test("L2 — 덱 도착은 더 이상 가이드를 띄우지 않는다 (조회와 분리)")
    func guide_notTiedToDeckLoad() async {
        let store = makeStore(homeGuide: SpyHomeGuide(seen: false), state: HomeState(rooms: fixtureRooms, isLoading: true))
        await store.send(.initialDeckLoaded(pins: fixturePins, roomID: "1")) {
            $0.pins = fixturePins
            $0.isLoading = false
        }
        #expect(!store.currentState.isGuidePresented)
        store.finish()   // showGuide 미수신 — 잔여 effect 없음
    }

    @Test("L1 — dismissGuide 는 가이드를 닫는다 (X 버튼)")
    func guide_dismisses() async {
        let store = makeStore(state: HomeState(isGuidePresented: true))
        await store.send(.dismissGuide) { $0.isGuidePresented = false }
        store.finish()
    }

    // MARK: - 재실행 시 이어 보기 (정책 3)

    @Test("L1 — swipeForward 는 인덱스를 1 증가시킨다")
    func swipeForward() async {
        let store = makeStore(state: HomeState(pins: fixturePins, currentCardIndex: 0))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.deckEndingToastFilter = .recommended   // 3장 덱이라 이 한 번으로 남은 2장 — 002-2-3 ② 예고
        }
        store.finish()
    }

    @Test("L1 — 마지막 카드에서 한 번 더 넘기면 덱 밖(소진)으로 나가고, 그 뒤로는 전진하지 않는다")
    func swipeForward_exitsDeckThenClamps() async {
        // 갈 곳이 없어야(마지막 방 + 마지막 미확인 정렬) 덱 밖에 머문다 — 그 상태의 인덱스를 검증한다.
        let store = makeStore(state: HomeState(
            rooms: [fixtureRooms[0]], selectedFilter: .nearby, pins: fixturePins, currentCardIndex: 2,
            viewedFilters: [.recommended, .latest], filterAnchor: .nearby
        ))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 3   // = pins.count → 소진 상태(002-3)
            $0.viewedFilters = [.recommended, .latest, .nearby]
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

    // 002-1-1 「홈 > 장소 상세 진입」 — 카드 탭은 상태를 건드리지 않고 전환만 낸다.

    @Test("L2 — tapCard 는 상세로 이동하면서 「경과일 초기화 확인」을 서버에 보낸다 (FR-007, TS-034)")
    func tapCard_navigatesAndRecordsAccess() async {
        let spy = SpyRecordPinAccess()
        let store = makeStore(recordPinAccess: spy, state: HomeState(pins: fixturePins))
        await store.send(.tapCard(PinID("pin-1")))
        // 상세가 사진·저장자·라벨을 그리려면 id 가 아니라 핀이 통째로 필요하다.
        await store.receive(.openPlaceDetail(fixturePins[1]))
        store.receiveNavigation(.openPlaceDetail(fixturePins[1]))
        store.finish()
        #expect(await spy.recorded == [PinID("pin-1")])
    }

    @Test("L2 — 카드 탭은 덱의 진행 상태를 바꾸지 않는다 (TS-013 — 「카드 열람 확인」이 아니다)")
    func tapCard_doesNotAdvanceDeck() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 1))
        await store.send(.tapCard(PinID("pin-1")))
        await store.receive(.openPlaceDetail(fixturePins[1]))
        store.receiveNavigation(.openPlaceDetail(fixturePins[1]))
        #expect(store.currentState.currentCardIndex == 1)
        #expect(store.currentState.pins.count == fixturePins.count)
        store.finish()
    }

    @Test("L2 — 넘김은 서버에 알리지 않는다 (TS-035 — 「카드 열람 확인」은 클라이언트 판정용)")
    func swipeForward_doesNotRecordAccess() async {
        let spy = SpyRecordPinAccess()
        let store = makeStore(recordPinAccess: spy, state: HomeState(rooms: fixtureRooms, pins: fixturePins))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.deckEndingToastFilter = .recommended
        }
        store.finish()
        #expect(await spy.recorded.isEmpty)
    }

    @Test("L1 — 덱에 없는 카드 탭은 아무 데도 가지 않는다")
    func tapCard_unknownPinDoesNothing() async {
        // 방·기준이 갈리는 순간에 들어온 탭 — 열어야 할 장소가 이미 덱에 없다.
        let store = makeStore(state: HomeState(pins: fixturePins))
        await store.send(.tapCard(PinID("pin-없음")))
        store.finish()
    }

    // MARK: - 방 우선 순회 (정책: 방 × 정렬, 정렬마다 최대 10장)

    @Test("L2 — 최초 진입은 마지막으로 본 방의 꾹 Pick 덱으로 시작한다")
    func initialLoad_startsAtLastViewedRoomWithRecommended() async {
        let room2 = deckPins("r2rec", room: "2", count: 3)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("2", .recommended): room2]),
            lastViewedRoom: SpyLastViewedRoom(stored: "2")
        )
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixtureRooms)) { $0.rooms = fixtureRooms }
        await store.receive(.initialDeckLoaded(pins: room2, roomID: "2")) {
            $0.currentRoomIndex = 1
            $0.pins = room2
            $0.isLoading = false
        }
        #expect(store.currentState.currentRoom?.id == "2")
        #expect(store.currentState.selectedFilter == .recommended)   // 진입 정렬은 항상 꾹 Pick
        store.finish()
    }

    @Test("L2 — 정렬 덱을 다 넘기면 다음 방이 아니라 이 방의 미확인 정렬로 자동 전환한다")
    func deckExhausted_switchesToNextUnviewedFilterInSameRoom() async {
        let latest = deckPins("latest", room: "1", count: 3)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .latest): latest]),
            state: HomeState(rooms: fixtureRooms, pins: deckPins("rec", room: "1", count: 1))
        )
        await store.send(.swipeForward) {   // 1장짜리 덱 → 한 번에 소진
            $0.currentCardIndex = 1
            $0.viewedFilters = [.recommended]
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoaded(pins: latest, roomID: "1", filter: .latest)) {
            $0.isDeckLoading = false
            $0.decks[.latest] = latest
            $0.currentCardIndex = 0
        }
        #expect(store.currentState.currentRoom?.id == "1")   // 방은 그대로
        store.finish()
    }

    @Test("L2 — 세 정렬을 모두 확인해야 다음 방으로 넘어가고, 방 변경 툴팁이 뜬다")
    func allFiltersViewed_movesToNextRoom() async {
        let room2 = deckPins("r2rec", room: "2", count: 2)
        let spy = SpyLastViewedRoom()
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("2", .recommended): room2]),
            lastViewedRoom: spy,
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .nearby,
                pins: deckPins("near", room: "1", count: 1),
                viewedFilters: [.recommended, .latest], filterAnchor: .nearby
            )
        )
        await store.send(.swipeForward) {
            $0.currentRoomIndex = 1
            $0.selectedFilter = .recommended   // 방 진입 정렬은 꾹 Pick
            $0.filterAnchor = .recommended     // 정렬 우선순위도 초기화
            $0.viewedFilters = []
            $0.decks = [:]
            $0.currentCardIndex = 0
            $0.changedRoomToastID = "2"        // 전환 안내
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoaded(pins: room2, roomID: "2", filter: .recommended)) {
            $0.isDeckLoading = false
            $0.decks[.recommended] = room2
            $0.deckEndingToastFilter = .recommended   // 2장뿐이라 도착하자마자 다음 정렬을 예고
        }
        #expect(store.currentState.filterOrder == [.recommended, .latest, .nearby])
        #expect(await spy.saved == ["2"])   // 이어 보기용 "마지막으로 본 방" 기록
        store.finish()
    }

    @Test("L2 — 수동으로 고른 정렬이 이후 자동 전환 순서의 기준이 된다 (최신순 → 꾹 Pick → 가까운순)")
    func manualFilter_becomesAnchorOfAutoSwitchOrder() async {
        let latest = deckPins("latest", room: "1", count: 1)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .latest): latest]),
            state: HomeState(rooms: fixtureRooms, pins: deckPins("rec", room: "1", count: 3))
        )
        await store.send(.selectFilter(.latest)) {
            $0.filterAnchor = .latest
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoaded(pins: latest, roomID: "1", filter: .latest)) {
            $0.isDeckLoading = false
            $0.decks[.latest] = latest
            $0.deckEndingToastFilter = .latest   // 1장뿐이라 도착하자마자 다음 정렬을 예고
        }
        #expect(store.currentState.filterOrder == [.latest, .recommended, .nearby])
        // 최신순을 다 넘기면 가까운순이 아니라 꾹 Pick 으로 — 받아 둔 덱이라 재조회 없이 즉시 전환한다.
        await store.send(.swipeForward) {
            $0.viewedFilters = [.latest]
            $0.selectedFilter = .recommended
            $0.deckEndingToastFilter = nil       // 옮기면서 지난 자리의 예고는 지운다
        }
        #expect(store.currentState.pins.count == 3)
        #expect(store.currentState.nextUnviewedFilter == .nearby)
        store.finish()
    }

    @Test("L2 — 빈 정렬은 건너뛰고 다음 미확인 정렬로 넘어간다")
    func emptyDeck_skipsToNextFilter() async {
        let nearby = deckPins("near", room: "1", count: 3)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .nearby): nearby]),   // 최신순은 0장
            state: HomeState(rooms: fixtureRooms, pins: deckPins("rec", room: "1", count: 1))
        )
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.viewedFilters = [.recommended]
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoaded(pins: [], roomID: "1", filter: .latest)) {
            $0.viewedFilters = [.recommended, .latest]   // 빈 정렬도 "확인한 것"으로 치고 넘어간다
            $0.selectedFilter = .nearby
            $0.currentCardIndex = 0
        }
        // 가까운순은 서버가 좌표를 요구한다 — 덱 조회 전에 위치를 한 번 얻어 들고 간다.
        await store.receive(.myCoordinateResolved(stubCoordinate)) {
            $0.myCoordinate = stubCoordinate
        }
        await store.receive(.deckLoaded(pins: nearby, roomID: "1", filter: .nearby)) {
            $0.isDeckLoading = false
            $0.decks[.nearby] = nearby
        }
        store.finish()
    }

    @Test("L2 — 한 정렬 덱은 최대 10장까지만 싣는다")
    func deck_capsAtTenCards() async {
        let twelve = deckPins("many", room: "1", count: 12)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .latest): twelve]),
            state: HomeState(rooms: fixtureRooms, pins: deckPins("rec", room: "1", count: 3))
        )
        let capped = Array(twelve.prefix(10))
        await store.send(.selectFilter(.latest)) {
            $0.filterAnchor = .latest
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoaded(pins: capped, roomID: "1", filter: .latest)) {
            $0.isDeckLoading = false
            $0.decks[.latest] = capped
        }
        #expect(store.currentState.pins.count == 10)
        store.finish()
    }

    @Test("L1 — 마지막 방의 마지막 정렬까지 넘기면 소진 화면으로 간다")
    func lastRoomLastFilter_entersAllViewed() async {
        let store = makeStore(state: HomeState(
            rooms: [fixtureRooms[0]], selectedFilter: .nearby,
            pins: deckPins("near", room: "1", count: 1),
            viewedFilters: [.recommended, .latest], filterAnchor: .nearby
        ))
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.viewedFilters = [.recommended, .latest, .nearby]
        }
        #expect(store.currentState.hasViewedAllPlaces)
        store.finish()
    }

    @Test("L2 — 덱이 바뀌면 되돌리기 이력이 끊긴다 — 첫 카드에서 뒤로 넘겨도 이전 덱으로 가지 않는다 (EC-003)")
    func swipeBackward_doesNotCrossDeckBoundary() async {
        var state = HomeState(
            rooms: fixtureRooms, selectedFilter: .latest,
            pins: deckPins("latest", room: "1", count: 2), viewedFilters: [.recommended]
        )
        state.decks[.recommended] = deckPins("rec", room: "1", count: 2)   // 앞서 보고 지나온 덱
        let store = makeStore(state: state)
        await store.send(.swipeBackward)   // 변화 없음 — 되돌리기는 현재 덱 안에서만 1단계
        #expect(store.currentState.selectedFilter == .latest)
        #expect(store.currentState.currentCardIndex == 0)
        store.finish()
    }

    @Test("L2 — 정렬 덱 조회가 실패하면 조회 직전 자리로 되돌려 기존 덱을 계속 보여준다")
    func deckLoadFailed_revertsToPreviousPosition() async {
        let rec = deckPins("rec", room: "1", count: 1)
        let state = HomeState(rooms: fixtureRooms, pins: rec)
        let store = makeStore(fetchPins: StubRoomDecks(failing: [deckKey("1", .latest)]), state: state)
        var revert = DeckPosition(state)
        revert.cardIndex = 1   // 덱을 다 넘겨 인덱스가 덱 밖으로 나간 시점에 조회가 시작됐다

        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.viewedFilters = [.recommended]
            $0.selectedFilter = .latest
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoadFailed(roomID: "1", filter: .latest, revertTo: revert)) {
            $0.isDeckLoading = false
            $0.selectedFilter = .recommended
            $0.viewedFilters = []     // 확인 기록도 되돌려 다시 넘기면 재시도된다
            $0.currentCardIndex = 0   // 덱 밖 인덱스는 복구한 덱의 마지막 카드로 clamp
        }
        #expect(store.currentState.pins == rec)
        store.finish()
    }

    @Test("L2 — 방 전환 중 덱 조회가 실패하면 옛 방의 덱·확인 기록·전환 안내까지 되돌린다")
    func roomMoveFailed_restoresPreviousRoomState() async {
        // 방 전환은 커서뿐 아니라 덱 캐시·확인 기록·우선순위까지 새 방 기준으로 갈아엎고 출발한다.
        // 실패했는데 커서만 되돌리면 옛 방의 카드가 사라진 빈 화면이 남는다.
        var state = HomeState(
            rooms: fixtureRooms, selectedFilter: .nearby,
            pins: deckPins("near", room: "1", count: 1),
            viewedFilters: [.recommended, .latest], filterAnchor: .nearby
        )
        state.decks[.recommended] = deckPins("rec", room: "1", count: 2)   // 옛 방에서 받아 둔 덱
        let store = makeStore(fetchPins: StubRoomDecks(failing: [deckKey("2", .recommended)]), state: state)
        var revert = DeckPosition(state)
        revert.cardIndex = 1

        await store.send(.swipeForward) {   // 방1 의 세 정렬을 다 봐 방2 로 이동 시도
            $0.currentRoomIndex = 1
            $0.selectedFilter = .recommended
            $0.filterAnchor = .recommended
            $0.viewedFilters = []
            $0.decks = [:]
            $0.currentCardIndex = 0
            $0.changedRoomToastID = "2"
            $0.isDeckLoading = true
        }
        await store.receive(.deckLoadFailed(roomID: "2", filter: .recommended, revertTo: revert)) {
            $0.isDeckLoading = false
            $0.currentRoomIndex = 0
            $0.selectedFilter = .nearby
            $0.filterAnchor = .nearby
            $0.viewedFilters = [.recommended, .latest]
            $0.decks = revert.decks
            $0.currentCardIndex = 0
            $0.changedRoomToastID = nil   // 옮긴 적 없으니 "…방이에요" 안내도 거둔다
        }
        #expect(store.currentState.currentRoom?.id == "1")
        #expect(store.currentState.pins.count == 1)          // 옛 방 덱이 살아 있다
        #expect(!store.currentState.showsEmptyState)         // 빈 화면(방 만들기 CTA)으로 떨어지지 않는다
        store.finish()
    }

    @Test("L1 — 지나간 자리(다른 방)의 응답은 화면을 움직이지 않는다")
    func staleDeckResponse_isIgnored() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins))
        await store.send(.deckLoaded(
            pins: deckPins("other", room: "2", count: 3), roomID: "2", filter: .recommended
        ))
        store.finish()
    }

    @Test("L1 — 보고 있는 방을 다시 고르면 시트만 닫고 덱을 다시 구성하지 않는다 (EC-014)")
    func selectRoom_sameRoomKeepsProgress() async {
        let deck = deckPins("rec", room: "1", count: 5)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .recommended): deck]),
            state: HomeState(rooms: fixtureRooms, pins: deck, currentCardIndex: 2, isRoomListPresented: true)
        )
        await store.send(.selectRoom("1")) { $0.isRoomListPresented = false }
        // 진행 상태가 그대로다 — 재구성했으면 커서가 0 으로 돌아가고 변경 툴팁이 떴을 것이다.
        #expect(store.currentState.currentCardIndex == 2)
        #expect(store.currentState.changedRoomToastID == nil)
        store.finish()   // 조회 effect 도 나가지 않는다
    }

    @Test("L2 — selectRoom 은 그 방의 꾹 Pick 덱으로 옮기고 시트를 닫으며 변경 툴팁을 세운다")
    func selectRoom_movesToThatRoomDeck() async {
        let room2 = deckPins("r2", room: "2", count: 3)
        let spy = SpyLastViewedRoom()
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("2", .recommended): room2]),
            lastViewedRoom: spy,
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .latest,
                pins: deckPins("latest", room: "1", count: 3),
                viewedFilters: [.recommended], filterAnchor: .latest, isRoomListPresented: true
            )
        )
        await store.send(.selectRoom("2")) {
            $0.isRoomListPresented = false
            $0.currentRoomIndex = 1
            $0.selectedFilter = .recommended
            $0.filterAnchor = .recommended
            $0.viewedFilters = []
            $0.decks = [:]
            $0.changedRoomToastID = "2"
            $0.isDeckLoading = true
            $0.isRoomUserChosen = true   // 직접 고른 방이라 비어 있어도 떠나지 않는다
        }
        await store.receive(.deckLoaded(pins: room2, roomID: "2", filter: .recommended)) {
            $0.isDeckLoading = false
            $0.decks[.recommended] = room2
            $0.isRoomUserChosen = false   // 카드를 봤으니 표시를 거둔다
        }
        #expect(await spy.saved == ["2"])
        store.finish()
    }

    @Test("currentRoom 은 카드가 아니라 순회 커서를 따른다")
    func currentRoom_followsCursor() {
        var state = HomeState(rooms: fixtureRooms, currentRoomIndex: 1)
        #expect(state.currentRoom?.id == "2")
        state.currentRoomIndex = 0
        #expect(state.currentRoom?.id == "1")
    }

    // MARK: - 직접 고른 방이 비었을 때 (FR-013 은 자동 전환의 규칙이고, TS-028 은 "그 방의 덱")

    @Test("L2 — 직접 고른 방의 세 정렬이 모두 비어도 다음 방으로 떠나지 않고 그 방에 남는다")
    func selectRoom_emptyRoomStaysPut() async {
        // **가운데 방**을 골라야 이 규칙이 검증된다 — 마지막 방이면 갈 곳이 없어(hasNextRoom == false)
        // 가드가 없어도 그 자리에 멈추므로, 규칙을 깨도 테스트가 통과해 버린다.
        let rooms = fixtureRooms + [
            Room(
                id: "3", type: .shared, name: "세 번째 방", description: nil,
                color: nil, ownerId: "owner-1", createdAt: fixtureDate,
                pinCount: 5, memberCount: 1, users: []
            )
        ]
        // 2번 방은 어느 정렬로도 카드가 없고, 3번 방에는 카드가 있다(가드가 없으면 그리로 끌려간다).
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("3", .recommended): deckPins("r3", room: "3", count: 3)]),
            state: HomeState(
                rooms: rooms,
                pins: deckPins("r1", room: "1", count: 3),
                isRoomListPresented: true
            )
        )
        // 중간 전이가 아니라 "결국 어느 방에 남았는가" 가 관심사다.
        store.exhaustive = false
        await store.send(.selectRoom("2"))
        // 세 정렬을 차례로 조회하고 모두 비어 그 자리에 멈춘다 — 3번 방으로 넘어가지 않는다.
        await store.receive(.deckLoaded(pins: [], roomID: "2", filter: .recommended))
        await store.receive(.deckLoaded(pins: [], roomID: "2", filter: .latest))
        await store.receive(.deckLoaded(pins: [], roomID: "2", filter: .nearby))

        #expect(store.currentState.currentRoomIndex == 1)          // 고른 방 그대로
        #expect(store.currentState.currentRoom?.id == "2")
        #expect(store.currentState.showsEmptyState)                 // 그 방의 빈 상태를 보여 준다
        store.finish()
    }

    @Test("L2 — 직접 고른 방의 꾹 Pick 이 비어도 그 방의 다른 정렬에 카드가 있으면 거기로 간다")
    func selectRoom_emptyFirstFilterStillShowsRoomCards() async {
        let latest = deckPins("r2-latest", room: "2", count: 2)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("2", .latest): latest]),
            state: HomeState(
                rooms: fixtureRooms,
                pins: deckPins("r1", room: "1", count: 3),
                isRoomListPresented: true
            )
        )
        store.exhaustive = false
        await store.send(.selectRoom("2"))
        await store.receive(.deckLoaded(pins: [], roomID: "2", filter: .recommended))
        await store.receive(.deckLoaded(pins: latest, roomID: "2", filter: .latest))

        // 방 안에서의 정렬 순회는 막지 않는다 — 막으면 있는 카드를 못 보여준다.
        #expect(store.currentState.currentRoom?.id == "2")
        #expect(store.currentState.selectedFilter == .latest)
        #expect(store.currentState.pins == latest)
        #expect(!store.currentState.showsEmptyState)
        store.finish()
    }

    @Test("L2 — 직접 고른 방의 카드를 본 뒤 소진하면 평소대로 다음 방으로 넘어간다(영구히 갇히지 않는다)")
    func selectRoom_afterSeeingCardsAutoAdvanceResumes() async {
        // 1번 방을 직접 고르고, 그 방의 카드를 본 뒤 세 정렬을 모두 소진시킨다.
        let deck = deckPins("r1", room: "1", count: 1)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .recommended): deck]),
            state: HomeState(
                rooms: fixtureRooms,
                pins: deckPins("r2", room: "2", count: 1),
                currentRoomIndex: 1,
                isRoomListPresented: true
            )
        )
        store.exhaustive = false
        await store.send(.selectRoom("1"))
        await store.receive(.deckLoaded(pins: deck, roomID: "1", filter: .recommended))
        #expect(!store.currentState.isRoomUserChosen)   // 카드를 본 순간 표시가 풀린다

        // 마지막 장을 넘기면 남은 정렬 → 다음 방 순회가 평소대로 이어진다.
        await store.send(.swipeForward)
        await store.receive(.deckLoaded(pins: [], roomID: "1", filter: .latest))
        await store.receive(.deckLoaded(pins: [], roomID: "1", filter: .nearby))
        #expect(store.currentState.currentRoom?.id == "2")   // 다음 방으로 넘어갔다
        store.finish()
    }

    @Test("nextUnviewedFilter — 미확인 정렬이 남아 있으면 그 정렬, 다 봤으면 nil(= 다음 방)")
    func nextUnviewedFilter_drivesTooltipCopy() {
        var state = HomeState(rooms: fixtureRooms, pins: fixturePins)
        #expect(state.nextUnviewedFilter == .latest)      // 기본 진입: 꾹 Pick → 최신순
        state.viewedFilters = [.latest]
        #expect(state.nextUnviewedFilter == .nearby)
        state.viewedFilters = [.latest, .nearby]
        #expect(state.nextUnviewedFilter == nil)          // 뷰가 "곧 다음 방으로 이동해요!" 로 파생
        // 가까운순을 직접 고르면: 가까운순 → 꾹 Pick → 최신순
        state = HomeState(rooms: fixtureRooms, selectedFilter: .nearby, pins: fixturePins, filterAnchor: .nearby)
        #expect(state.nextUnviewedFilter == .recommended)
    }

    @Test("L1 — 갈 곳이 없으면(마지막 방·마지막 정렬) 예고 툴팁을 띄우지 않는다")
    func deckEndingToast_skipsWhenNowhereToGo() async {
        let store = makeStore(state: HomeState(
            rooms: [fixtureRooms[0]], selectedFilter: .nearby,
            pins: deckPins("near", room: "1", count: 4), currentCardIndex: 1,
            viewedFilters: [.recommended, .latest], filterAnchor: .nearby
        ))
        await store.send(.swipeForward) { $0.currentCardIndex = 2 }   // 남은 2장이지만 예고할 곳이 없다
        store.finish()
    }

    @Test("L2 — 가까운순 위치 권한을 거부하면 그 덱을 소진으로 보고 같은 방의 남은 덱으로 넘어간다 (EC-009)")
    func nearbyPermissionDenied_treatsDeckAsExhausted() async {
        let latest = deckPins("latest", room: "1", count: 3)
        let store = makeStore(
            fetchPins: StubRoomDecks(decks: [deckKey("1", .latest): latest]),
            currentLocation: StubCurrentLocation(result: .permissionDenied),
            state: HomeState(
                rooms: fixtureRooms, selectedFilter: .recommended,
                pins: deckPins("rec", room: "1", count: 1),
                filterAnchor: .nearby   // 가까운순을 직접 골랐던 방 → 소진 후 가까운순이 먼저 온다
            )
        )
        // 꾹 Pick 을 소진 → 다음 미확인 정렬인 가까운순으로 간다.
        await store.send(.swipeForward) {
            $0.currentCardIndex = 1
            $0.viewedFilters = [.recommended]
            $0.selectedFilter = .nearby
            $0.isDeckLoading = true
        }
        // 권한 거부 → 실패로 되돌리지 않고 "후보 0건" 으로 받아 다음 자리로 넘어간다.
        await store.receive(.deckLoaded(pins: [], roomID: "1", filter: .nearby)) {
            $0.currentCardIndex = 0
            $0.viewedFilters = [.recommended, .nearby]
            $0.selectedFilter = .latest      // 이 방에 남은 덱(최신순)으로
        }
        await store.receive(.deckLoaded(pins: latest, roomID: "1", filter: .latest)) {
            $0.isDeckLoading = false
            $0.decks[.latest] = latest
        }
        #expect(store.currentState.currentRoom?.id == "1")   // 방을 넘기지 않았다
        store.finish()
    }

    // MARK: - 전 방 소진 (002-3 「모든 카드를 다 봤을 때」)

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
                 color: nil, ownerId: "o", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []),
            Room(id: "b", type: .shared, name: "모임", description: nil,
                 color: nil, ownerId: "o", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []),
        ]
        // 현재 툴팁은 방 "b" 를 가리킴. 이전 방 "a" 타이머의 뒤늦은 dismiss 가 도착.
        let store = makeStore(state: HomeState(rooms: sameName, changedRoomToastID: "b"))
        await store.send(.dismissRoomToast("a"))   // 이름은 같지만 id 가 달라 무시(이름 기반이면 잘못 지웠을 것)
        #expect(store.currentState.changedRoomToastID == "b")
        await store.send(.dismissRoomToast("b")) { $0.changedRoomToastID = nil }   // 같은 id 는 정상 숨김
        store.finish()
    }

    // MARK: - 덱 끝 예고 툴팁 (Figma 002-2-3 ②)

    /// 한 방짜리 4장 덱 — index 1 에서 한 번 넘기면 남은 카드가 2장이 되는 크기.
    private func deckOfFour() -> [Pin] {
        (0..<4).map { i in
            PinFixture.pin(id: PinID("c-\(i)"), roomID: "1", category: .savedByMany,
                title: "C\(i)", address: "주소", createdAt: fixtureDate)
        }
    }

    @Test("L1 — 남은 카드가 2장이 되는 순간 다음 기준 전환을 예고하고, 한 장 더 넘겨도 다시 뜨지 않는다")
    func deckEndingToast_raisesWhenTwoLeft() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: deckOfFour(), currentCardIndex: 1))
        await store.send(.swipeForward) {   // 남은 3 → 2 = 예고
            $0.currentCardIndex = 2
            $0.deckEndingToastFilter = .recommended
        }
        await store.send(.dismissDeckEndingToast(.recommended)) { $0.deckEndingToastFilter = nil }
        // 3초 뒤 사라진 툴팁이 마지막 한 장을 넘길 때 다시 뜨면 성가시다 — 2장이 "되는 순간"만 예고한다.
        await store.send(.swipeForward) { $0.currentCardIndex = 3 }
        store.finish()
    }

    @Test("L1 — dismissDeckEndingToast 는 기준이 바뀐 뒤 뒤늦게 오면 새 툴팁을 지우지 않는다")
    func dismissDeckEndingToast_ignoresStaleFilter() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, deckEndingToastFilter: .latest))
        await store.send(.dismissDeckEndingToast(.recommended))   // 지난 기준 타이머의 뒤늦은 dismiss — 무시
        #expect(store.currentState.deckEndingToastFilter == .latest)
        await store.send(.dismissDeckEndingToast(.latest)) { $0.deckEndingToastFilter = nil }
        store.finish()
    }

    @Test("L1 — tapCreateRoom 은 시트를 닫고 goToCreateRoom 으로 navigate 한다")
    func tapCreateRoom_dismissesAndNavigates() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isRoomListPresented: true))
        await store.send(.tapCreateRoom) { $0.isRoomListPresented = false }
        store.receiveNavigation(.goToCreateRoom)
        store.finish()
    }

    // MARK: - 다른 방 저장 → 「홈 방 시트」 (FR-005 / FR-018)

    /// 시트를 연 상태 — 카드 `pin-0`(방 "1" 소속)의 저장 시트.
    private var openedSavePostState: HomeState {
        HomeState(
            rooms: fixtureRooms,
            pins: fixturePins,
            savePost: SavePostState(pinID: PinID("pin-0"), savedRoomID: "1")
        )
    }

    @Test("L1 — tapSaveToOtherRoom 은 카드가 속한 방을 '이미 담긴 방'으로 두고 시트를 연다 (TS-011)")
    func tapSaveToOtherRoom_opensSheetWithOwningRoomChecked() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 1))
        await store.send(.tapSaveToOtherRoom(PinID("pin-0"))) {
            $0.savePost = SavePostState(pinID: PinID("pin-0"), savedRoomID: "1")
        }
        // TS-011: 덱의 진행 상태는 그대로다.
        #expect(store.currentState.currentCardIndex == 1)
        store.finish()
    }

    @Test("L1 — 덱에 없는 카드로 열면 이미 담긴 방 없이 시트만 연다")
    func tapSaveToOtherRoom_unknownPinHasNoSavedRoom() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: fixturePins))
        await store.send(.tapSaveToOtherRoom(PinID("없는-핀"))) {
            $0.savePost = SavePostState(pinID: PinID("없는-핀"))
        }
        store.finish()
    }

    @Test("L2 — 방을 누르는 즉시 그 방에 저장하고, 끝나면 시트를 닫고 완료 토스트를 띄운다 (FR-018 — 확정 버튼 없음)")
    func savePostToRoom_savesImmediately() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: openedSavePostState)

        await store.send(.savePostToRoom("2")) { $0.savePost?.isSaving = true }
        await store.receive(.savePostFinished) {
            $0.savePost = nil
            $0.savedToastID = 1
        }
        store.finish()

        let saved = await spy.saved
        #expect(saved.count == 1)
        #expect(saved.first?.pinID == PinID("pin-0"))
        #expect(saved.first?.roomIDs == ["2"])
    }

    @Test("L1 — 이미 담긴 방은 눌러도 저장하지 않는다(중복 저장 차단 — 서버도 409 로 막는다)")
    func savePostToRoom_ignoresOwningRoom() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: openedSavePostState)
        await store.send(.savePostToRoom("1"))   // 변화 없음
        store.finish()
        #expect(await spy.saved.isEmpty)
    }

    @Test("L1 — 저장 중 다른 방을 눌러도 저장이 두 번 나가지 않는다")
    func savePostToRoom_ignoredWhileSaving() async {
        let spy = SpySavePin()
        var state = openedSavePostState
        state.savePost?.isSaving = true
        let store = makeStore(savePin: spy, state: state)
        await store.send(.savePostToRoom("2"))   // 변화 없음 — effect 도 나가지 않는다(finish 가 검사)
        store.finish()
        #expect(await spy.saved.isEmpty)
    }

    @Test("L2 — 저장이 실패하면 시트를 저장 전 상태로 되돌려 다시 시도할 수 있다")
    func savePostToRoom_failureRestoresSheet() async {
        let store = makeStore(savePin: ThrowingSavePin(), state: openedSavePostState)

        await store.send(.savePostToRoom("2")) { $0.savePost?.isSaving = true }
        await store.receive(.savePostFailed) { $0.savePost?.isSaving = false }
        // 시트가 살아 있어 그대로 재시도된다.
        #expect(store.currentState.savePost?.pinID == PinID("pin-0"))
        #expect(store.currentState.savedToastID == nil)   // 실패는 완료 토스트를 띄우지 않는다
        store.finish()
    }

    @Test("L2 — 저장 중 시트를 닫아도 저장은 끝까지 진행돼 완료 토스트가 뜬다")
    func dismissSavePost_whileSavingStillCompletes() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: openedSavePostState)

        await store.send(.savePostToRoom("2")) { $0.savePost?.isSaving = true }
        // 저장이 도는 사이 스와이프로 시트를 닫는다.
        await store.send(.dismissSavePost) { $0.savePost = nil }
        // 진행 중이던 저장은 잘리지 않고 끝나 토스트로 이어진다 — 시트가 없어도 토스트는 뜬다.
        await store.receive(.savePostFinished) { $0.savedToastID = 1 }
        store.finish()

        #expect(await spy.saved.count == 1)   // 닫혔다고 저장이 취소되지 않는다
    }

    @Test("L1 — 장소 상세 공유 완료는 공유 문구를 쓴다 ([SYS-003], TS-033)")
    func sharedToOtherRooms_marksToastAsShareCopy() async {
        // 같은 토스트 자리를 쓰지만 문구는 [SYS-003] 쪽이다(place-detail 2.2.0 TS-033).
        let store = makeStore(state: HomeState(rooms: fixtureRooms))
        await store.send(.sharedToOtherRooms) {
            $0.savedToastKind = .shared
            $0.savedToastID = 1
        }
        store.finish()
    }

    @Test("L1 — 홈 카드 저장 완료는 저장 문구를 쓴다 ([SYS-002])")
    func savePostFinished_marksToastAsSaveCopy() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, savedToastKind: .shared))
        await store.send(.savePostFinished) {
            $0.savedToastKind = .saved
            $0.savedToastID = 1
        }
        store.finish()
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
            color: nil, ownerId: "owner-1", createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
        )
    }
}
