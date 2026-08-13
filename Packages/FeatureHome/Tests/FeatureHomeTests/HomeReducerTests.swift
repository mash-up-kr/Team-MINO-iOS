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

@MainActor
struct HomeReducerTests {
    private func makeStore(
        _ useCase: FetchRoomsUseCase = StubFetchRooms(),
        state: HomeState = HomeState()
    ) -> TestStore<HomeState, HomeAction, HomeNav> {
        TestStore(state, reduce: homeReducer(fetchRooms: useCase))
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
            $0.isLoading = false
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
            $0.isLoading = false
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

    // MARK: - Empty state

    @Test("rooms 가 비어있으면 isEmpty 가 true")
    func isEmpty_true() {
        let state = HomeState(rooms: [], isLoading: false)
        #expect(state.isEmpty)
    }

    @Test("rooms 가 있으면 isEmpty 가 false")
    func isEmpty_false() {
        let state = HomeState(rooms: fixtureRooms)
        #expect(!state.isEmpty)
    }

    @Test("로딩 중이어도 rooms 가 비어있으면 isEmpty 가 true")
    func isEmpty_true_during_loading() {
        let state = HomeState(rooms: [], isLoading: true)
        #expect(state.isEmpty)
    }

    // MARK: - Filter

    @Test("L1 — selectFilter 는 selectedFilter 를 갱신한다")
    func selectFilter() async {
        let store = makeStore()
        await store.send(.selectFilter(2)) {
            $0.selectedFilter = 2
        }
        store.finish()
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

    @Test("L1 — pinsLoaded 는 pins 를 세팅하고 인덱스를 0 으로 리셋한다")
    func pinsLoaded() async {
        let store = makeStore(state: HomeState(currentCardIndex: 5))
        await store.send(.pinsLoaded(fixturePins)) {
            $0.pins = fixturePins
            $0.currentCardIndex = 0
        }
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

    @Test("L1 — swipeForward 는 마지막 카드에서 clamp 된다")
    func swipeForward_clamps() async {
        let store = makeStore(state: HomeState(pins: fixturePins, currentCardIndex: 2))
        await store.send(.swipeForward)
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

    @Test("L1 — tapMore 는 상태를 변경하지 않는다")
    func tapMore_noop() async {
        let store = makeStore(state: HomeState(pins: fixturePins))
        await store.send(.tapMore(PinID("pin-0")))
        store.finish()
    }

    @Test("L1 — tapMorePlaces 는 이전 배치를 제외한 새 카드 10개를 재생성하고 인덱스를 0 으로 리셋한다")
    func tapMorePlaces_regenerates() async {
        let store = makeStore(
            state: HomeState(rooms: fixtureRooms, pins: fixturePins, currentCardIndex: 2)
        )
        store.exhaustive = false   // 재생성 pins 는 mock(createdAt: .now)이라 정확 값 예측 불가
        let previousIDs = Set(fixturePins.map(\.id))

        await store.send(.tapMorePlaces)

        #expect(store.currentState.pinBatches["1"] == 1)
        #expect(store.currentState.currentCardIndex == 0)
        #expect(store.currentState.pins.count == 10)
        // "이전꺼 제외" — 재생성된 카드의 식별자는 이전 배치와 겹치지 않는다
        #expect(store.currentState.pins.allSatisfy { !previousIDs.contains($0.id) })
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

    @Test("L1 — 마지막 방 마지막 카드에서 swipeForward 는 clamp 된다(고정)")
    func swipeForward_clampsAtVeryLastCard() async {
        // index 4 = 방2(마지막 방) 마지막 카드
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 4))
        await store.send(.swipeForward)   // 변화 없음
        store.finish()
    }

    @Test("L1 — tapMorePlaces 는 현재 방 구간만 새 배치로 교체하고 그 방 첫 카드로 리셋한다")
    func tapMorePlaces_replacesOnlyCurrentRoomSlice() async {
        // index 4 = 방2 카드 → 방2 구간만 재생성
        let store = makeStore(state: HomeState(rooms: fixtureRooms, pins: multiRoomPins(), currentCardIndex: 4))
        store.exhaustive = false

        await store.send(.tapMorePlaces)

        #expect(store.currentState.pinBatches["2"] == 1)
        #expect(store.currentState.pinBatches["1"] == nil)          // 방1 은 건드리지 않음
        #expect(store.currentState.currentCardIndex == 3)           // 방2 구간 시작
        #expect(store.currentState.pins.count == 13)               // 방1 3장 유지 + 방2 새 10장
        #expect(store.currentState.pins.prefix(3).allSatisfy { $0.roomID == "1" })
        #expect(store.currentState.pins.dropFirst(3).allSatisfy { $0.roomID == "2" })
        #expect(store.currentState.currentRoom?.id == "2")
        store.finish()
    }

    // MARK: - 방 선택 바텀 시트

    @Test("L1 — tapRoomBadge 는 방 선택 시트를 연다")
    func tapRoomBadge_presents() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms))
        await store.send(.tapRoomBadge) { $0.isRoomListPresented = true }
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
            $0.changedRoomToast = "데이트 코스"       // 툴팁은 뷰에서 "…방이에요" 를 붙인다
        }
        store.finish()
    }

    @Test("L1 — dismissRoomToast 는 같은 방 툴팁을 숨긴다")
    func dismissRoomToast_hides() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, changedRoomToast: "민방"))
        await store.send(.dismissRoomToast("민방")) { $0.changedRoomToast = nil }
        store.finish()
    }

    @Test("L1 — dismissRoomToast 는 다른 방으로 바뀌었으면 툴팁을 지우지 않는다")
    func dismissRoomToast_ignoresStaleName() async {
        // 방을 바꿔 툴팁이 "데이트 코스"인데, 이전 방("민방") 타이머의 dismiss 가 뒤늦게 도착한 상황
        let store = makeStore(state: HomeState(rooms: fixtureRooms, changedRoomToast: "데이트 코스"))
        await store.send(.dismissRoomToast("민방"))   // 상태 변화 없음 — 새 방 툴팁 유지
        store.finish()
    }

    @Test("L1 — tapCreateRoom 은 시트를 닫고 goToCreateRoom 으로 navigate 한다")
    func tapCreateRoom_dismissesAndNavigates() async {
        let store = makeStore(state: HomeState(rooms: fixtureRooms, isRoomListPresented: true))
        await store.send(.tapCreateRoom) { $0.isRoomListPresented = false }
        store.receiveNavigation(.goToCreateRoom)
        store.finish()
    }

    // MARK: - 방 이름 표기

    @Test("공동방은 표기 이름에 '방'을 붙이고, 개인방(내 장소)은 붙이지 않는다")
    func homeDisplayName_suffixByType() {
        let personal = Room(
            id: "0", type: .personal, name: "내 장소", description: nil,
            color: "#00BDDE", ownerId: "owner-1", inviteCode: "MYROOM",
            createdAt: fixtureDate, pinCount: 0, memberCount: 1, users: []
        )
        #expect(fixtureRooms[0].homeDisplayName == "맛집 탐방방")   // 공동방
        #expect(personal.homeDisplayName == "내 장소")             // 개인방 — 접미사 없음
    }
}
