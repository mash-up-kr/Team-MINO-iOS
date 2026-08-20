import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureRooms: [Room] = [
    Room(
        id: "r1", type: .personal, name: "내 장소", description: nil, color: "#00BDDE",
        ownerId: "u1", inviteCode: "C1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: 1, users: []
    ),
    Room(
        id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: "#FFC06E",
        ownerId: "u1", inviteCode: "C2", createdAt: Date(timeIntervalSince1970: 0),
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
    private func makeStore(
        _ useCase: FetchRoomsUseCase = StubFetchRooms(),
        state: RoomListState = RoomListState()
    ) -> TestStore<RoomListState, RoomListAction, RoomListNav> {
        TestStore(state, reduce: roomListReducer(useCase: useCase))
    }

    @Test("L2 — load 하면 rooms 를 반영한다. 공동방이 있으면 유도 시트는 뜨지 않는다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixtureRooms)) { $0.rooms = fixtureRooms }
        #expect(!store.currentState.isCreatePromptPresented)
        store.finish()
    }

    // 기획 001-2-1 — 활성 조건은 "공동방 미생성". 개인방만 있는 건 없는 것으로 친다.
    @Test("L2 — 공동방이 하나도 없으면 load 후 생성 유도 시트가 뜬다")
    func load_withoutSharedRoom_showsCreatePrompt() async {
        let personalOnly = [fixtureRooms[0]]
        let store = makeStore(StubFetchRooms(result: .success(personalOnly)))

        await store.send(.load)
        await store.receive(.loaded(personalOnly)) {
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
        await store.receive(.loaded(personalOnly)) {
            $0.rooms = personalOnly
            $0.skipsNextCreatePrompt = false
        }
        #expect(!store.currentState.isCreatePromptPresented)

        // 다음 탭 진입 — 다시 뜬다
        await store.send(.load)
        await store.receive(.loaded(personalOnly)) { $0.isCreatePromptPresented = true }

        store.finish()
    }

    @Test("L1 — dismissCreatePrompt(나중에 만들래요) 는 시트만 닫는다")
    func dismissCreatePrompt_closesOnly() async {
        let store = makeStore(state: RoomListState(isCreatePromptPresented: true))

        await store.send(.dismissCreatePrompt) { $0.isCreatePromptPresented = false }

        // finish 가 미수신 navigation 잔여를 검사한다 — 닫기만 했는데 전환이 나갔다면 실패한다
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
        await store.receive(.loaded(personalOnly)) { $0.isCreatePromptPresented = true }

        store.finish()
    }

    @Test("L2 — load 실패 시 loadFailed 를 받고 rooms 는 비어 있다")
    func load_failure() async {
        let store = makeStore(StubFetchRooms(result: .failure(.roomsFetchFailed)))
        await store.send(.load)
        await store.receive(.loadFailed(.roomsFetchFailed))
        store.finish()
    }

    @Test("L1 — selectFilter 는 filter 인덱스를 갱신한다")
    func selectFilter() async {
        let store = makeStore()
        await store.send(.selectFilter(2)) { $0.filter = 2 }
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
