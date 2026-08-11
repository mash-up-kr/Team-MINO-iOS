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

    @Test("L2 — load 하면 rooms 를 반영한다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixtureRooms)) { $0.rooms = fixtureRooms }
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
