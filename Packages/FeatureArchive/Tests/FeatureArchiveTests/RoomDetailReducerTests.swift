import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

private let fixtureRoom = Room(
    id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: .orange,
    ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
    pinCount: 3, memberCount: 2, users: []
)

/// 업종을 카페 2 · 음식점 1 로 섞는다 — 칩을 눌렀을 때 실제로 걸러지는지 보려면 섞여 있어야 한다.
private let fixtureCategories = ["카페", "음식점", "카페"]

private let fixturePins: [Pin] = zip([0, 10, 20], fixtureCategories).map { daysAgo, placeCategory in
    PinFixture.pin(
        id: PinID("p\(daysAgo)"),
        roomID: fixtureRoom.id,
        category: .worthVisiting,
        title: "장소 \(daysAgo)",
        address: "주소 \(daysAgo)",
        placeCategory: placeCategory,
        createdAt: fixtureNow.addingTimeInterval(-Double(daysAgo) * 86_400)
    )
}

private struct StubFetchPins: FetchPinsUseCase {
    var result: Result<[Pin], DomainError> = .success(fixturePins)

    func execute(rooms: [Room], filter: PinFilter) async throws -> [Pin] { try pins() }
    func execute(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] { try pins() }

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

    private func locations(_ sort: RoomDetailSort) -> [RoomDetailLocation] {
        RoomDetailSorting.apply(sort, to: fixturePins, now: fixtureNow).map(RoomDetailLocation.init(from:))
    }

    private func loadedState() -> RoomDetailState {
        RoomDetailState(
            room: RoomDetailRoom(from: fixtureRoom),
            pins: fixturePins,
            locations: locations(.all),
            categories: RoomDetailCategoryList.make(from: fixturePins)
        )
    }

    @Test("L2 — load 하면 핀을 원본과 표시 목록에 모두 반영한다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixturePins)) {
            $0.pins = fixturePins
            $0.locations = locations(.all)
            $0.categories = ["전체", "카페", "음식점"]   // 담긴 장소의 업종에서 생성(004-1 ⑨)
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
        #expect(store.currentState.locations.count == fixturePins.count)   // 최신순은 걸러내지 않는다
        store.finish()
    }

    @Test("L1 — selectCategory 는 그 업종만 남긴다")
    func selectCategory() async {
        let store = makeStore(state: loadedState())
        await store.send(.selectCategory("음식점")) {
            $0.category = "음식점"
            $0.locations = [RoomDetailLocation(from: fixturePins[1])]
        }
        store.finish()
    }

    @Test("L1 — '전체' 로 되돌리면 다시 다 보인다")
    func selectCategory_backToAll() async {
        var state = loadedState()
        state.category = "음식점"
        state.locations = [RoomDetailLocation(from: fixturePins[1])]
        let store = makeStore(state: state)

        await store.send(.selectCategory("전체")) {
            $0.category = "전체"
            $0.locations = locations(.all)
        }
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

    @Test("L1 — tapLocation 은 그 장소의 핀을 실어 navigate 한다")
    func tapLocation() async {
        let store = makeStore(state: loadedState())
        await store.send(.tapLocation(fixturePins[1].id.value))
        store.receiveNavigation(.openPlaceDetail(fixturePins[1]))
        store.finish()
    }

    @Test("L1 — 목록에 없는 장소를 탭하면 아무 일도 일어나지 않는다")
    func tapLocation_unknownID() async {
        let store = makeStore(state: loadedState())
        await store.send(.tapLocation("없는-id"))
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
