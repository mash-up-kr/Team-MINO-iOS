import Core
import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureRooms: [Room] = [
    Room(
        id: "r1", type: .personal, name: "내 장소", description: nil, color: nil,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: 1, users: []
    ),
    Room(
        id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: .orange,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 3, memberCount: 2, users: []
    ),
]

private struct StubCurrentLocation: CurrentLocationUseCase {
    var result: CurrentLocationResult = .coordinate(Coordinate(latitude: 37.4966, longitude: 127.0530))
    func execute() async -> CurrentLocationResult { result }
}

/// 진입 권한 묶음을 흉내 낸다. 위치 결과만 돌려주고 호출 횟수를 센다 — 알림까지 이어 물을지의
/// 판단은 Domain 이 하므로(``RequestEntryPermissionsUseCase``) 화면 테스트는 그걸 보지 않는다.
private final class SpyEntryPermissions: RequestEntryPermissionsUseCase, @unchecked Sendable {
    var result: CurrentLocationResult = .coordinate(Coordinate(latitude: 37.4966, longitude: 127.0530))
    private(set) var callCount = 0
    func execute() async -> CurrentLocationResult {
        callCount += 1
        return result
    }
}

/// 지도 마커용 핀. 두 방에 하나씩 둬 **마커마다 소속 방 색이 달라야 한다**는 규칙을 볼 수 있게 한다.
private let fixturePins: [Pin] = [
    PinFixture.pin(
        id: PinID("p1"), roomID: "r1", category: .worthVisiting,
        title: "개인방 장소", address: "a", createdAt: Date(timeIntervalSince1970: 0)
    ),
    PinFixture.pin(
        id: PinID("p2"), roomID: "r2", category: .worthVisiting,
        title: "공동방 장소", address: "b", createdAt: Date(timeIntervalSince1970: 0)
    ),
]

private struct StubFetchPins: FetchRoomPinsUseCase {
    var resultsBySort: [PinSort: [Pin]] = [:]
    var resultsByCategory: [PlaceCategoryFilter: [Pin]] = [:]
    var result: Result<[Pin], DomainError> = .success(fixturePins)

    func execute(
        roomID: String?,
        sort: PinSort,
        category: PlaceCategoryFilter,
        origin: Coordinate?
    ) async throws -> [Pin] {
        if let pins = resultsByCategory[category] { return pins }
        if let pins = resultsBySort[sort] { return pins }
        switch result {
        case .success(let pins): return pins
        case .failure(let error): throw error
        }
    }
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

@MainActor
struct RoomListReducerTests {
    /// 테스트끼리 스누즈 기록이 섞이지 않도록 매번 새 suite 를 쓴다.
    private func makeSnooze(snoozed: Bool = false) -> SnoozeSwitch {
        let name = "RoomListReducerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let sut = SnoozeSwitch(key: "prompt", period: .days(14), defaults: defaults)
        if snoozed { sut.snooze() }
        return sut
    }

    private func makeStore(
        _ useCase: FetchRoomsUseCase = StubFetchRooms(),
        fetchPins: FetchRoomPinsUseCase = StubFetchPins(),
        state: RoomListState = RoomListState(),
        snooze: SnoozeSwitch? = nil,
        location: CurrentLocationUseCase = StubCurrentLocation(),
        entryPermissions: RequestEntryPermissionsUseCase? = nil
    ) -> TestStore<RoomListState, RoomListAction, RoomListNav> {
        // 진입 스텁을 따로 안 주면 위치 스텁과 같은 결과를 돌려주게 맞춘다 — 기존 테스트들이
        // `location:` 하나만 넘겨도 진입 경로가 같은 값을 보게 하기 위해서다.
        let entry = entryPermissions ?? {
            let spy = SpyEntryPermissions()
            spy.result = (location as? StubCurrentLocation)?.result ?? spy.result
            return spy
        }()
        return TestStore(
            state,
            reduce: roomListReducer(
                useCase: useCase,
                fetchPins: fetchPins,
                promptSnooze: snooze ?? makeSnooze(),
                currentLocation: location,
                entryPermissions: entry
            )
        )
    }

    @Test("L2 — load 하면 rooms 를 반영한다. 공동방이 있으면 유도 시트는 뜨지 않는다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixtureRooms, pins: fixturePins, isPromptSnoozed: false)) {
            $0.rooms = fixtureRooms
            $0.pins = fixturePins
        }
        #expect(!store.currentState.isCreatePromptPresented)
        store.finish()
    }

    // 기획 001-2-1 — 활성 조건은 "공동방 미생성". 개인방만 있는 건 없는 것으로 친다.
    @Test("L2 — 공동방이 하나도 없으면 load 후 생성 유도 시트가 뜬다")
    func load_withoutSharedRoom_showsCreatePrompt() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(StubFetchRooms(result: .success(personalOnly)))

        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: false)) {
            $0.pins = fixturePins
            $0.rooms = personalOnly
            $0.isCreatePromptPresented = true
        }

        store.finish()
    }

    @Test("L2 — tapCreateRoom 은 유도 시트를 닫고 만들기 화면으로 보낸다")
    func tapCreateRoom_dismissesPromptAndNavigates() async {
        let store = makeStore(state: RoomListState(isCreatePromptPresented: true))

        await store.send(.tapCreateRoom) {
            $0.isCreatePromptPresented = false
            $0.skipsNextCreatePrompt = true
        }
        store.receiveNavigation(.goToCreateRoom)

        store.finish()
    }

    // pop 하면 이 화면의 .task 가 다시 돌아 .load 가 나간다. 억제하지 않으면 방금 그 시트에서
    // 출발한 사용자에게 같은 시트가 즉시 다시 뜬다("나가기 → 시트 → 나가기" 반복).
    @Test("L2 — 만들기 화면에서 돌아온 직후의 재조회는 유도 시트를 다시 띄우지 않는다")
    func reload_rightAfterReturningFromCreation_skipsPromptOnce() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(
            StubFetchRooms(result: .success(personalOnly)),
            state: RoomListState(isCreatePromptPresented: true)
        )

        await store.send(.tapCreateRoom) {
            $0.isCreatePromptPresented = false
            $0.skipsNextCreatePrompt = true
        }
        store.receiveNavigation(.goToCreateRoom)

        // 복귀 직후 1회 — 억제하고 플래그를 소비한다
        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: false)) {
            $0.pins = fixturePins
            $0.rooms = personalOnly
            $0.skipsNextCreatePrompt = false
        }
        #expect(!store.currentState.isCreatePromptPresented)

        // 다음 탭 진입 — 다시 뜬다
        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: false)) {
            $0.isCreatePromptPresented = true
            $0.pins = fixturePins
        }

        store.finish()
    }

    @Test("L1 — dismissCreatePrompt(스와이프로 내림) 는 시트만 닫고 미루지 않는다")
    func dismissCreatePrompt_closesOnly() async {
        let snooze = makeSnooze()
        let store = makeStore(state: RoomListState(isCreatePromptPresented: true), snooze: snooze)

        await store.send(.dismissCreatePrompt) { $0.isCreatePromptPresented = false }

        #expect(!snooze.isSnoozed)
        // finish 가 미수신 navigation 잔여를 검사한다 — 닫기만 했는데 전환이 나갔다면 실패한다
        store.finish()
    }

    // 기획: "나중에 만들래요" 클릭 시 2주 동안 바텀시트를 활성화하지 않는다.
    @Test("L2 — tapLater(나중에 만들래요) 는 시트를 닫고 2주 미룬다")
    func tapLater_closesAndSnoozes() async {
        let snooze = makeSnooze()
        let store = makeStore(state: RoomListState(isCreatePromptPresented: true), snooze: snooze)

        await store.send(.tapLater) { $0.isCreatePromptPresented = false }

        #expect(snooze.isSnoozed)
        store.finish()
    }

    @Test("L2 — 미뤄 둔 동안에는 공동방이 0개여도 시트가 뜨지 않는다")
    func load_whileSnoozed_doesNotShowPrompt() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(StubFetchRooms(result: .success(personalOnly)), snooze: makeSnooze(snoozed: true))

        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: true)) {
            $0.rooms = personalOnly
            $0.pins = fixturePins
        }

        #expect(!store.currentState.isCreatePromptPresented)
        store.finish()
    }

    // 거절을 기억하지 않는다 — 저장 탭에 다시 들어오면(.load 재실행) 또 뜬다(기획서 그대로).
    @Test("L2 — 시트를 닫아도 재조회하면 다시 뜬다")
    func reload_afterDismiss_showsPromptAgain() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(
            StubFetchRooms(result: .success(personalOnly)),
            state: RoomListState(rooms: personalOnly, isCreatePromptPresented: false)
        )

        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: false)) {
            $0.isCreatePromptPresented = true
            $0.pins = fixturePins
        }

        store.finish()
    }

    @Test("L2 — load 실패 시 loadFailed 를 받고 rooms 는 비어 있다")
    func load_failure() async {
        let store = makeStore(StubFetchRooms(result: .failure(.roomsFetchFailed)))
        await store.send(.load)
        await store.receive(.loadFailed(.roomsFetchFailed))
        store.finish()
    }

    // 실패가 플래그를 안 지우면 true 로 남아, 그 다음 정상 진입의 시트가 조용히 안 뜬다.
    @Test("L2 — 복귀 로드가 실패해도 억제 플래그는 소비된다")
    func loadFailure_afterReturningFromCreation_stillConsumesSkipFlag() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(
            StubFetchRooms(result: .success(personalOnly)),
            state: RoomListState(isCreatePromptPresented: true)
        )

        await store.send(.tapCreateRoom) {
            $0.isCreatePromptPresented = false
            $0.skipsNextCreatePrompt = true
        }
        store.receiveNavigation(.goToCreateRoom)

        // 복귀 로드가 실패 — 여기서 플래그를 소비해야 한다
        await store.send(.loadFailed(.roomsFetchFailed)) { $0.skipsNextCreatePrompt = false }

        // 다음 정상 진입에서는 정상적으로 뜬다
        await store.send(.load)
        await store.receive(.loaded(personalOnly, pins: fixturePins, isPromptSnoozed: false)) {
            $0.pins = fixturePins
            $0.rooms = personalOnly
            $0.isCreatePromptPresented = true
        }

        store.finish()
    }

    @Test("L1 — selectFilter 는 filter 인덱스를 갱신한다")
    func selectFilter() async {
        let store = makeStore()
        await store.send(.selectFilter(2)) { $0.filter = 2 }
        store.finish()
    }

    // 지도 위 드롭다운은 **마커를 다시 받는다** — 정렬을 서버가 하므로 화면은 기준만 바꿔 요청한다.
    // 방 카드 목록(`rooms`)은 건드리지 않는다: 이 칩은 지도 소관이다.
    @Test("L2 — selectRoomSort 는 그 기준으로 마커를 다시 받고 방 목록은 건드리지 않는다")
    func selectRoomSort() async {
        let reordered = fixturePins.reversed().map { $0 }
        let store = makeStore(
            fetchPins: StubFetchPins(resultsBySort: [.latest: reordered]),
            state: RoomListState(rooms: fixtureRooms, filter: 2)
        )

        await store.send(.selectRoomSort(.latest)) { $0.roomSort = .latest }
        await store.receive(.pinsLoaded(reordered, for: PinQuery(sort: .latest))) { $0.pins = reordered }

        #expect(store.currentState.rooms == fixtureRooms)
        store.finish()
    }

    @Test("L1 — 같은 기준을 다시 고르면 요청을 내지 않는다")
    func selectRoomSort_sameValueDoesNotRefetch() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, roomSort: .latest))
        await store.send(.selectRoomSort(.latest))
        store.finish()   // 요청이 나갔다면 미처리 effect 로 여기서 걸린다
    }

    @Test("L2 — 늦게 온 마커 응답은 버린다")
    func pinsLoaded_discardsStaleResponse() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, roomSort: .latest))

        await store.send(.pinsLoaded([], for: PinQuery(sort: .comment)))

        #expect(store.currentState.pins.isEmpty)   // 원래 비어 있었고, 늦은 응답으로도 채우지 않는다
        store.finish()
    }

    // 거리순만 좌표를 요구한다 — 좌표 없이 `sort=distance` 를 보내면 서버가 400 이다.
    @Test("L2 — 거리순은 좌표를 먼저 받고 나서야 마커를 다시 받는다")
    func selectRoomSort_distance() async {
        let nearby = [fixturePins[1]]
        let store = makeStore(
            fetchPins: StubFetchPins(resultsBySort: [.distance: nearby]),
            state: RoomListState(rooms: fixtureRooms)
        )

        await store.send(.selectRoomSort(.distance)) { $0.isLocatingForSort = true }
        #expect(store.currentState.roomSort == .all)   // 좌표 전에는 세우지 않는다

        let origin = Coordinate(latitude: 37.4966, longitude: 127.0530)
        await store.receive(.sortLocationResolved(.coordinate(origin))) {
            $0.isLocatingForSort = false
            $0.myCoordinate = origin
            $0.roomSort = .distance
        }
        await store.receive(.pinsLoaded(nearby, for: PinQuery(sort: .distance))) { $0.pins = nearby }
        store.finish()
    }

    @Test("L2 — 좌표를 못 얻으면 정렬은 고르기 전 값 그대로다")
    func selectRoomSort_distance_permissionDenied() async {
        let store = makeStore(
            state: RoomListState(rooms: fixtureRooms),
            location: StubCurrentLocation(result: .permissionDenied)
        )

        await store.send(.selectRoomSort(.distance)) { $0.isLocatingForSort = true }
        await store.receive(.sortLocationResolved(.permissionDenied)) { $0.isLocatingForSort = false }

        #expect(store.currentState.roomSort == .all)
        #expect(store.currentState.myCoordinate == nil)
        store.finish()   // 마커 재조회가 나갔다면 미처리 effect 로 여기서 걸린다
    }

    // 003-1 ① — "5가지로 필터링하여 볼 수 있다 / '전체'로 기본 선택되어있다".
    // 방 개수에 따라 늘고 주는 목록이 아니다(방 상세 004-1 ⑥ 과 같은 고정 5가지).
    @Test("003-1 ① — 드롭다운 기본값은 '전체' 이고 항목은 5가지다")
    func roomSort_defaultIsAll() {
        #expect(RoomListState().roomSort == .all)
        #expect(PinSort.allCases.count == 5)
    }

    @Test("L1 — loaded 는 방이 줄어도 드롭다운 선택을 건드리지 않는다")
    func loaded_shrink_keepsRoomSort() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, roomSort: .comment))
        // 유도 시트는 이 테스트의 관심사가 아니라 스누즈로 꺼 둔다.
        await store.send(.loaded([fixtureRooms[0]], pins: fixturePins, isPromptSnoozed: true)) {
            $0.pins = fixturePins
            $0.rooms = [fixtureRooms[0]]
        }
        #expect(store.currentState.roomSort == .comment)
        store.finish()
    }

    // spec FR-004 — "개인방(`내 장소`)이 최상단에 고정된 방 카드 목록".
    // 서버가 개인방을 어디에 두든 목록 맨 위여야 한다.
    @Test("FR-004 — loaded 는 개인방을 목록 맨 위로 올린다")
    func loaded_pinsPersonalRoomToTop() async {
        let sharedFirst = [fixtureRooms[1], fixtureRooms[0]]   // 서버가 공동방을 먼저 준 경우
        let store = makeStore()

        await store.send(.loaded(sharedFirst, pins: fixturePins, isPromptSnoozed: true)) {
            $0.pins = fixturePins
            $0.rooms = [fixtureRooms[0], fixtureRooms[1]]
        }
        store.finish()
    }

    // 개인방끼리·공동방끼리의 서버 순서는 건드리지 않는다(안정 분할).
    @Test("FR-004 — 공동방 사이의 서버 순서는 그대로 둔다")
    func personalFirst_isStable() {
        let a = fixtureRooms[1]
        let b = Room(
            id: "r3", type: .shared, name: "두 번째 공동방", description: nil, color: .blue,
            ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0, memberCount: 1, users: []
        )

        #expect(personalFirst([a, b, fixtureRooms[0]]).map(\.id) == ["r1", "r2", "r3"])
    }

    // spec FR-007 — "생성 완료 시 [SCR-005] 방 상세로 직행".
    // 만들기 화면은 id 만 주고 상세는 방 전체를 필요로 해서, 재조회 응답에서 찾아 연다.
    @Test("FR-007 — 만든 방이 재조회로 도착하면 그 방 상세로 넘어간다")
    func openCreatedRoom_waitsForReload() async {
        let store = makeStore()

        await store.send(.openCreatedRoom("r2")) { $0.pendingOpenRoomID = "r2" }
        await store.send(.loaded(fixtureRooms, pins: fixturePins, isPromptSnoozed: true)) {
            $0.pins = fixturePins
            $0.rooms = fixtureRooms
            $0.pendingOpenRoomID = nil
        }
        store.receiveNavigation(.openRoomDetail(fixtureRooms[1]))
        store.finish()
    }

    // 공유 시트 경로처럼 목록이 이미 살아 있으면 기다릴 것이 없다.
    @Test("FR-007 — 이미 목록에 있는 방이면 곧바로 연다")
    func openCreatedRoom_opensImmediatelyIfLoaded() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms))

        await store.send(.openCreatedRoom("r2"))
        store.receiveNavigation(.openRoomDetail(fixtureRooms[1]))
        store.finish()
    }

    // 방을 만든 직후라 유도 시트가 뜰 이유가 없다 — 상세로 넘어가는 길에 시트가 겹치면 안 된다.
    @Test("FR-007 — 상세로 넘어가는 응답은 유도 시트를 띄우지 않는다")
    func openCreatedRoom_doesNotShowCreatePrompt() async {
        var state = RoomListState()
        state.pendingOpenRoomID = "r1"
        let store = makeStore(state: state)

        // 개인방만 있는 응답 = 평소라면 유도 시트가 뜨는 조건이다.
        await store.send(.loaded([fixtureRooms[0]], pins: fixturePins, isPromptSnoozed: false)) {
            $0.pins = fixturePins
            $0.rooms = [fixtureRooms[0]]
            $0.pendingOpenRoomID = nil
        }
        store.receiveNavigation(.openRoomDetail(fixtureRooms[0]))
        #expect(!store.currentState.isCreatePromptPresented)
        store.finish()
    }

    // 003-1 ⑦ — 현위치 버튼.
    @Test("L2 — tapMyLocation 은 좌표를 얻으면 지도 카메라를 옮긴다")
    func tapMyLocation_focusesMap() async {
        let coordinate = Coordinate(latitude: 37.4966, longitude: 127.0530)
        let store = makeStore(location: StubCurrentLocation(result: .coordinate(coordinate)))
        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.coordinate(coordinate))) {
            $0.isLocating = false
            // 받아 온 좌표를 화면에 남긴다 — 진입 카메라의 기준점이라, 안 남기면 요청이 끝나는
            // 순간 카메라가 진입 때 잡아 둔 옛 좌표로 되돌아간다(이슈 #189).
            $0.myCoordinate = coordinate
        }
        store.receiveNavigation(.focusMyLocation(coordinate))
        store.finish()
    }

    @Test("L2 — 현위치 버튼이 진입 카메라의 기준점을 최신 좌표로 갈아 끼운다")
    func tapMyLocation_updatesEntryCoordinate() async {
        let stale = Coordinate(latitude: 37.4979, longitude: 127.0276)
        let fresh = Coordinate(latitude: 37.5443, longitude: 127.0557)
        var state = RoomListState()
        state.myCoordinate = stale

        let store = makeStore(
            state: state,
            location: StubCurrentLocation(result: .coordinate(fresh))
        )

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.coordinate(fresh))) {
            $0.isLocating = false
            $0.myCoordinate = fresh
        }
        store.receiveNavigation(.focusMyLocation(fresh))
        store.finish()
    }

    @Test("L2 — 좌표를 못 얻으면 기준점을 건드리지 않는다")
    func myLocationDenied_keepsEntryCoordinate() async {
        let known = Coordinate(latitude: 37.5443, longitude: 127.0557)
        var state = RoomListState()
        state.myCoordinate = known

        let store = makeStore(state: state, location: StubCurrentLocation(result: .permissionDenied))

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.permissionDenied)) { $0.isLocating = false }
        store.finish()
    }

    // 시안에 실패를 알리는 UI 가 없다 — 지도는 기본 카메라(강남)에 머문다.
    @Test("L2 — 권한이 없으면 아무 데도 옮기지 않는다")
    func tapMyLocation_permissionDenied_doesNothing() async {
        let store = makeStore(location: StubCurrentLocation(result: .permissionDenied))
        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.permissionDenied)) { $0.isLocating = false }
        store.finish()
    }

    @Test("L1 — 요청이 진행 중이면 연타를 무시한다(권한 팝업 이중 노출 방지)")
    func tapMyLocation_whileLocating_ignored() async {
        var state = RoomListState()
        state.isLocating = true
        let store = makeStore(state: state)
        await store.send(.tapMyLocation)
        store.finish()
    }


    // PRD [SYS-004] Flow A — 저장 탭 진입 시의 위치 권한 요청. 버튼(⑦)과 달리 카메라를 옮기지
    // 않고 기준점만 세운다 — 그 좌표를 진입 카메라가 읽는다.
    @Test("L2 — 진입 요청이 좌표를 받으면 기준점만 세우고 카메라는 옮기지 않는다")
    func requestLocationOnEntry_setsCoordinateWithoutMovingCamera() async {
        let coordinate = Coordinate(latitude: 37.5443, longitude: 127.0557)
        let store = makeStore(location: StubCurrentLocation(result: .coordinate(coordinate)))

        await store.send(.requestLocationOnEntry)
        await store.receive(.entryLocationResolved(.coordinate(coordinate))) {
            $0.myCoordinate = coordinate
        }
        // navigation 이 하나도 없어야 한다 — `focusMyLocation` 은 버튼 전용이다.
        // 잔여 검사(`finish`)가 이걸 대신 단언한다.
        #expect(!store.currentState.isLocating)
        store.finish()
    }

    // 진입 경로는 위치만이 아니라 **권한 묶음**을 부른다 — 여기서 안 부르면 새로 설치한 사용자는
    // 알림을 묻는 자리를 잃는다(``RequestEntryPermissionsUseCase``).
    @Test("L2 — 진입 요청은 위치가 아니라 진입 권한 묶음을 부른다")
    func requestLocationOnEntry_callsEntryPermissions() async {
        let coordinate = Coordinate(latitude: 37.5443, longitude: 127.0557)
        let entry = SpyEntryPermissions()
        entry.result = .coordinate(coordinate)
        let store = makeStore(entryPermissions: entry)

        await store.send(.requestLocationOnEntry)
        await store.receive(.entryLocationResolved(.coordinate(coordinate))) { $0.myCoordinate = coordinate }

        #expect(entry.callCount == 1)
        store.finish()
    }

    @Test("L1 — 좌표를 이미 들고 있으면 다시 묻지 않는다")
    func requestLocationOnEntry_skipsWhenCoordinateKnown() async {
        var state = RoomListState()
        state.myCoordinate = Coordinate(latitude: 37.4979, longitude: 127.0276)
        let store = makeStore(state: state)

        await store.send(.requestLocationOnEntry)
        store.finish()
    }

    // 거부는 조용히 지나간다 — 그때 카메라가 기본 좌표(강남역)로 떨어지는 것이 곧 PRD 의
    // "거부: 기본 디폴트 좌표를 중심점으로 세팅" 이다.
    @Test("L2 — 진입 요청이 거부되면 기준점은 비어 있는 채로 남는다")
    func requestLocationOnEntry_deniedKeepsCoordinateNil() async {
        let store = makeStore(location: StubCurrentLocation(result: .permissionDenied))

        await store.send(.requestLocationOnEntry)
        await store.receive(.entryLocationResolved(.permissionDenied))
        #expect(store.currentState.myCoordinate == nil)
        store.finish()
    }

    // 진입 `.task` 와 버튼 연타가 겹치면 권한 팝업이 두 번 뜬다.
    @Test("L1 — 버튼 요청이 진행 중이면 진입 요청을 내지 않는다")
    func requestLocationOnEntry_whileLocating_ignored() async {
        var state = RoomListState()
        state.isLocating = true
        let store = makeStore(state: state)

        await store.send(.requestLocationOnEntry)
        store.finish()
    }

    @Test("L1 — 거리순 정렬의 측위가 진행 중이어도 진입 요청을 내지 않는다")
    func requestLocationOnEntry_whileLocatingForSort_ignored() async {
        var state = RoomListState()
        state.isLocatingForSort = true
        let store = makeStore(state: state)

        await store.send(.requestLocationOnEntry)
        store.finish()
    }
    @Test("L2 — selectCategory 는 그 칩으로 마커를 다시 받는다")
    func selectCategory() async {
        let onlyOne = [fixturePins[1]]
        let store = makeStore(
            fetchPins: StubFetchPins(resultsByCategory: [.restaurant: onlyOne]),
            state: RoomListState(rooms: fixtureRooms, filter: 2)
        )

        await store.send(.selectCategory(.restaurant)) { $0.category = .restaurant }
        await store.receive(.pinsLoaded(onlyOne, for: PinQuery(category: .restaurant))) { $0.pins = onlyOne }

        #expect(store.currentState.rooms == fixtureRooms)
        store.finish()
    }

    @Test("L1 — 같은 칩을 다시 고르면 요청을 내지 않는다")
    func selectCategory_sameValueDoesNotRefetch() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, category: .cafe))
        await store.send(.selectCategory(.cafe))
        store.finish()
    }

    // PRD [SYS-004] — "마커 클릭: … 하단 시트가 [SCR-006] 장소 상세 `Half` 로 전환된다".
    // 방을 먼저 고르게 하지 않는다(중복 장소 마커도 같다).
    @Test("L1 — 지도 마커를 누르면 그 장소 상세로 navigate 한다")
    func tapPin() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms))
        await store.send(.pinsLoaded(fixturePins, for: PinQuery())) { $0.pins = fixturePins }

        await store.send(.tapPin("p2"))
        store.receiveNavigation(.openPlaceDetail(fixturePins[1]))
        store.finish()
    }

    @Test("L1 — 목록에 없는 마커 id 는 무시한다")
    func tapPin_unknownID() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms))
        await store.send(.tapPin("없는-핀"))
        store.finish()   // navigate 가 나갔다면 미처리 nav 로 여기서 걸린다
    }

    @Test("L1 — tapRoom 은 고른 방을 실어 방 상세로 navigate 한다")
    func tapRoom() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms))
        await store.send(.tapRoom(fixtureRooms[1]))
        store.receiveNavigation(.openRoomDetail(fixtureRooms[1]))
        store.finish()
    }

    @Test("L2 — 이미 rooms 가 있는 상태에서 재조회가 실패해도 기존 rooms 를 비우지 않는다")
    func load_failure_afterPreviousSuccess_keepsExistingRooms() async {
        // 재진입(pull-to-refresh 등) 시나리오: 첫 로드는 성공, 두 번째 로드가 실패해도
        // loadFailed 가 rooms 를 건드리지 않아야 화면이 빈 리스트로 깜빡이지 않는다.
        let store = makeStore(state: RoomListState(rooms: fixtureRooms))
        // expect 클로저를 비워 두면 TestStore 가 "state 가 전혀 안 바뀜"을 단언한다(exhaustive 기본값).
        // rooms 가 조금이라도 달라지면(예: 실수로 비워버리면) 이 send 단계에서 바로 실패한다.
        await store.send(.loadFailed(.roomsFetchFailed))
        store.finish()
    }
}
