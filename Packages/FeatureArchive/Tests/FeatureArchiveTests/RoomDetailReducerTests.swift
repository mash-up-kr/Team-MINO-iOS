import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

private let fixtureRoom = Room(
    id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: "#FFC06E",
    ownerId: "u1", inviteCode: "C2", createdAt: Date(timeIntervalSince1970: 0),
    pinCount: 3, memberCount: 2, users: []
)

/// 0·10·20 일 전 3건. 10일 전까지가 "최근 14일" 안이다.
private let fixturePins: [Pin] = [0, 10, 20].map { daysAgo in
    Pin(
        id: PinID("p\(daysAgo)"),
        roomID: fixtureRoom.id,
        category: .worthVisiting,
        title: "장소 \(daysAgo)",
        address: "주소 \(daysAgo)",
        createdAt: fixtureNow.addingTimeInterval(-Double(daysAgo) * 86_400)
    )
}

private struct StubFetchPins: FetchPinsUseCase {
    var result: Result<[Pin], DomainError> = .success(fixturePins)

    func execute(rooms: [Room]) async throws -> [Pin] { try pins() }
    func execute(room: Room, page: Int) async throws -> [Pin] { try pins() }

    private func pins() throws -> [Pin] {
        switch result {
        case .success(let pins): return pins
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct RoomDetailReducerTests {
    private func makeStore(
        _ useCase: FetchPinsUseCase = StubFetchPins(),
        state: RoomDetailState = RoomDetailState(room: RoomDetailRoom(from: fixtureRoom))
    ) -> TestStore<RoomDetailState, RoomDetailAction, RoomDetailNav> {
        TestStore(state, reduce: roomDetailReducer(useCase: useCase, room: fixtureRoom, now: { fixtureNow }))
    }

    /// 정렬을 적용한 뒤의 표시 목록.
    private func locations(_ sort: RoomDetailSort) -> [RoomDetailLocation] {
        RoomDetailSorting.apply(sort, to: fixturePins, now: fixtureNow).map(RoomDetailLocation.init(from:))
    }

    private func loadedState() -> RoomDetailState {
        RoomDetailState(
            room: RoomDetailRoom(from: fixtureRoom),
            pins: fixturePins,
            locations: locations(.all)
        )
    }

    @Test("L2 — load 하면 핀을 원본과 표시 목록에 모두 반영한다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixturePins)) {
            $0.pins = fixturePins
            $0.locations = locations(.all)
        }
        store.finish()
    }

    @Test("L2 — load 실패 시 loadFailed 를 받고 목록은 비어 있다")
    func load_failure() async {
        let store = makeStore(StubFetchPins(result: .failure(.unknown)))
        await store.send(.load)
        await store.receive(.loadFailed(.unknown))
        store.finish()
    }

    @Test("L2 — 이미 목록이 있는 상태에서 재조회가 실패해도 기존 목록을 비우지 않는다")
    func load_failure_keepsExistingLocations() async {
        let store = makeStore(state: loadedState())
        // expect 를 비워 두면 TestStore 가 "state 가 전혀 안 바뀜"을 단언한다(exhaustive 기본값).
        await store.send(.loadFailed(.unknown))
        store.finish()
    }

    @Test("L1 — selectSort 는 정렬값과 표시 목록을 함께 갱신한다")
    func selectSort() async {
        let store = makeStore(state: loadedState())
        await store.send(.selectSort(.latest)) {
            $0.sort = .latest
            $0.locations = locations(.latest)
        }
        // 20일 전 핀은 14일 밖이라 빠진다 — 정렬이 실제로 걸렸는지 개수로 확인한다.
        #expect(store.currentState.locations.count == 2)
        store.finish()
    }

    @Test("L1 — selectCategory 는 카테고리만 바꾸고 목록은 건드리지 않는다")
    func selectCategory() async {
        let store = makeStore(state: loadedState())
        await store.send(.selectCategory(.cafe)) { $0.category = .cafe }
        store.finish()
    }

    @Test("L1 — selectViewMode 는 보기 방식만 갱신한다")
    func selectViewMode() async {
        let store = makeStore(state: loadedState())
        await store.send(.selectViewMode(.grid)) { $0.viewMode = .grid }
        store.finish()
    }

    @Test("L1 — tapClose 는 close 로 navigate 한다")
    func tapClose() async {
        let store = makeStore(state: loadedState())
        await store.send(.tapClose)
        store.receiveNavigation(.close)
        store.finish()
    }

    @Test("L1 — tapShare 는 고른 장소를 실어 navigate 한다")
    func tapShare() async {
        let store = makeStore(state: loadedState())
        let target = locations(.all)[0]
        await store.send(.tapShare(target))
        store.receiveNavigation(.shareLocation(target))
        store.finish()
    }
}
