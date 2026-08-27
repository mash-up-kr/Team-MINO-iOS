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
        snooze: SnoozeSwitch? = nil
    ) -> TestStore<RoomListState, RoomListAction, RoomListNav> {
        TestStore(state, reduce: roomListReducer(useCase: useCase, promptSnooze: snooze ?? makeSnooze()))
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

    @Test("L1 — selectRoomFilter 는 roomFilter 만 갱신한다")
    func selectRoomFilter() async {
        let store = makeStore(state: RoomListState(rooms: fixtureRooms, filter: 2))
        await store.send(.selectRoomFilter(1)) { $0.roomFilter = 1 }
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
