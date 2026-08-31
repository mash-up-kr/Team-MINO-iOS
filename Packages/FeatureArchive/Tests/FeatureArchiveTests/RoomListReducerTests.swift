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
        state: RoomListState = RoomListState(),
        snooze: SnoozeSwitch? = nil,
        location: CurrentLocationUseCase = StubCurrentLocation()
    ) -> TestStore<RoomListState, RoomListAction, RoomListNav> {
        TestStore(
            state,
            reduce: roomListReducer(
                useCase: useCase,
                promptSnooze: snooze ?? makeSnooze(),
                currentLocation: location
            )
        )
    }

    @Test("L2 — load 하면 rooms 를 반영한다. 공동방이 있으면 유도 시트는 뜨지 않는다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixtureRooms, isPromptSnoozed: false)) { $0.rooms = fixtureRooms }
        #expect(!store.currentState.isCreatePromptPresented)
        store.finish()
    }

    // 기획 001-2-1 — 활성 조건은 "공동방 미생성". 개인방만 있는 건 없는 것으로 친다.
    @Test("L2 — 공동방이 하나도 없으면 load 후 생성 유도 시트가 뜬다")
    func load_withoutSharedRoom_showsCreatePrompt() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(StubFetchRooms(result: .success(personalOnly)))

        await store.send(.load)
        await store.receive(.loaded(personalOnly, isPromptSnoozed: false)) {
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
        await store.receive(.loaded(personalOnly, isPromptSnoozed: false)) {
            $0.rooms = personalOnly
            $0.skipsNextCreatePrompt = false
        }
        #expect(!store.currentState.isCreatePromptPresented)

        // 다음 탭 진입 — 다시 뜬다
        await store.send(.load)
        await store.receive(.loaded(personalOnly, isPromptSnoozed: false)) { $0.isCreatePromptPresented = true }

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
        await store.receive(.loaded(personalOnly, isPromptSnoozed: true)) { $0.rooms = personalOnly }

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
        await store.receive(.loaded(personalOnly, isPromptSnoozed: false)) { $0.isCreatePromptPresented = true }

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
        await store.receive(.loaded(personalOnly, isPromptSnoozed: false)) {
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

    @Test("L1 — selectRoomSort 는 roomSort 만 갱신한다")
    func selectRoomSort() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, filter: 2))
        await store.send(.selectRoomSort(.latest)) { $0.roomSort = .latest }
        store.finish()
    }

    // 003-1 ① — "5가지로 필터링하여 볼 수 있다 / '전체'로 기본 선택되어있다".
    // 방 개수에 따라 늘고 주는 목록이 아니다(방 상세 004-1 ⑥ 과 같은 고정 5가지).
    @Test("003-1 ① — 드롭다운 기본값은 '전체' 이고 항목은 5가지다")
    func roomSort_defaultIsAll() {
        #expect(RoomListState().roomSort == .all)
        #expect(RoomDetailSort.allCases.count == 5)
    }

    @Test("L1 — loaded 는 방이 줄어도 드롭다운 선택을 건드리지 않는다")
    func loaded_shrink_keepsRoomSort() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, roomSort: .comment))
        // 유도 시트는 이 테스트의 관심사가 아니라 스누즈로 꺼 둔다.
        await store.send(.loaded([fixtureRooms[0]], isPromptSnoozed: true)) {
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

        await store.send(.loaded(sharedFirst, isPromptSnoozed: true)) {
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
        await store.send(.loaded(fixtureRooms, isPromptSnoozed: true)) {
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
        await store.send(.loaded([fixtureRooms[0]], isPromptSnoozed: false)) {
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
        await store.receive(.myLocationResolved(.coordinate(coordinate))) { $0.isLocating = false }
        store.receiveNavigation(.focusMyLocation(coordinate))
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

    @Test("L1 — selectCategory 는 categoryFilter 만 갱신한다")
    func selectCategory() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, filter: 2))
        await store.send(.selectCategory(2)) { $0.categoryFilter = 2 }
        store.finish()
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
