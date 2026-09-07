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

/// 거리순(004-1 ⑥)의 기준점. 아래 핀들을 여기서 북쪽으로 밀어 거리를 만든다.
private let fixtureOrigin = Coordinate(latitude: 37.5443, longitude: 127.0557)

/// p0 는 3km 반경 **밖**, p10·p20 은 안이다. 입력 순서를 거리와 어긋나게 둬 재정렬을 확인한다.
private let fixtureDistances: [Double] = [5_000, 2_000, 300]

private let fixturePins: [Pin] = zip(zip([0, 10, 20], fixtureCategories), fixtureDistances)
    .map { pair, metersAway in
        let (daysAgo, placeCategory) = pair
        return PinFixture.pin(
            id: PinID("p\(daysAgo)"),
            roomID: fixtureRoom.id,
            category: .worthVisiting,
            title: "장소 \(daysAgo)",
            address: "주소 \(daysAgo)",
            coordinate: PinFixture.coordinate(metersAway, northOf: fixtureOrigin),
            placeCategory: placeCategory,
            createdAt: fixtureNow.addingTimeInterval(-Double(daysAgo) * 86_400)
        )
    }

/// 정렬·필터를 **서버가 한다**는 전제의 스텁. 기준마다 다른 순서를 돌려주어, 화면이 자기 규칙으로
/// 다시 줄 세우지 않고 **받은 순서를 그대로** 그리는지 확인할 수 있게 한다.
private struct StubFetchPins: FetchRoomPinsUseCase {
    /// 기준별 응답. 없는 기준은 `result` 로 떨어진다.
    var resultsBySort: [PinSort: [Pin]] = [:]
    /// 카테고리별 응답. 정렬보다 먼저 본다 — 카테고리 테스트가 정렬 응답에 가려지지 않게.
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

private struct StubDeletePin: DeletePinUseCase {
    var error: DomainError?

    func execute(pinID: PinID) async throws {
        if let error { throw error }
    }
}

/// `fixtureRoom.ownerId` 가 "u1" 이라 기본값은 **방장 본인**이다.
private struct StubCurrentMember: CurrentMemberUseCase {
    var result: Result<MemberProfile, DomainError> = .success(owner)

    static let owner = MemberProfile(id: MemberID("u1"), nickname: "방장", avatarColor: .violet)
    static let member = MemberProfile(id: MemberID("u9"), nickname: "멤버", avatarColor: .red)

    func execute() async throws -> MemberProfile {
        switch result {
        case .success(let profile): return profile
        case .failure(let error): throw error
        }
    }
}

/// 기본값은 **허용 + 좌표 있음** — 거리순이 실제로 걸리는 경로가 기본이라야 나머지 테스트가 방해받지 않는다.
private struct StubCurrentLocation: CurrentLocationUseCase {
    var result: CurrentLocationResult = .coordinate(fixtureOrigin)

    func execute() async -> CurrentLocationResult { result }
}

@MainActor
struct RoomDetailReducerTests {
    private func makeStore(
        _ useCase: FetchRoomPinsUseCase = StubFetchPins(),
        deletePin: DeletePinUseCase = StubDeletePin(),
        currentMember: CurrentMemberUseCase = StubCurrentMember(),
        currentLocation: CurrentLocationUseCase = StubCurrentLocation(),
        state: RoomDetailState = RoomDetailState(room: RoomDetailRoom(from: fixtureRoom))
    ) -> TestStore<RoomDetailState, RoomDetailAction, RoomDetailNav> {
        TestStore(
            state,
            reduce: roomDetailReducer(
                useCase: useCase,
                deletePin: deletePin,
                fetchCurrentMember: currentMember,
                currentLocation: currentLocation,
                room: fixtureRoom
            )
        )
    }

    /// 삭제 확인 다이얼로그가 열린 상태 — 케밥에서 "장소 삭제" 를 누른 직후.
    private func deletingState(
        _ index: Int,
        pins: [Pin] = fixturePins,
        category: PlaceCategoryFilter = .all
    ) -> RoomDetailState {
        var state = loadedState(pins: pins, category: category)
        state.deletion = RoomDetailDeletion(locationID: fixturePins[index].id.value)
        return state
    }

    /// 표시 목록은 **받은 순서 그대로** 매핑한 것이다 — 화면이 다시 줄 세우지 않는다.
    private func locations(_ pins: [Pin] = fixturePins) -> [RoomDetailLocation] {
        pins.map(RoomDetailLocation.init(from:))
    }

    private func loadedState(
        pins: [Pin] = fixturePins,
        sort: PinSort = .all,
        category: PlaceCategoryFilter = .all
    ) -> RoomDetailState {
        RoomDetailState(
            room: RoomDetailRoom(from: fixtureRoom),
            pins: pins,
            locations: locations(pins),
            sort: sort,
            category: category
        )
    }

    @Test("L2 — load 하면 핀을 원본과 표시 목록에 모두 반영한다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load)
        await store.receive(.loaded(fixturePins, for: PinQuery())) {
            $0.pins = fixturePins
            $0.locations = locations()
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

    // 정렬은 **서버가** 한다 — 화면은 기준만 바꿔 다시 요청하고 받은 순서를 그대로 그린다.
    @Test("L2 — selectSort 는 그 기준으로 다시 조회하고 받은 순서를 그대로 그린다")
    func selectSort() async {
        let reordered = fixturePins.reversed().map { $0 }   // 서버가 다른 순서를 준 상황
        let store = makeStore(
            StubFetchPins(resultsBySort: [.latest: reordered]),
            state: loadedState()
        )

        await store.send(.selectSort(.latest)) { $0.sort = .latest }
        await store.receive(.loaded(reordered, for: PinQuery(sort: .latest))) {
            $0.pins = reordered
            $0.locations = locations(reordered)
        }

        // 클라이언트가 다시 줄 세우지 않았다는 확인 — 서버가 준 순서 그대로다.
        #expect(store.currentState.locations.map(\.id) == reordered.map(\.id.value))
        store.finish()
    }

    @Test("L1 — 같은 기준을 다시 고르면 요청을 내지 않는다")
    func selectSort_sameValueDoesNotRefetch() async {
        let store = makeStore(state: loadedState(sort: .latest))
        await store.send(.selectSort(.latest))
        store.finish()   // 요청이 나갔다면 미처리 effect 로 여기서 걸린다
    }

    // 정렬을 연달아 바꾸면 먼저 낸 요청이 나중에 도착할 수 있다.
    @Test("L2 — 늦게 온 응답은 버린다 — 지금 고른 기준의 목록만 남는다")
    func loaded_discardsStaleResponse() async {
        let stale = [fixturePins[0]]
        let store = makeStore(state: loadedState(sort: .latest))

        await store.send(.loaded(stale, for: PinQuery(sort: .comment)))

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations())
        store.finish()
    }

    // 카테고리도 서버가 거른다 — 화면은 칩만 바꿔 다시 요청한다.
    @Test("L2 — selectCategory 는 그 칩으로 다시 조회한다")
    func selectCategory() async {
        let onlyRestaurant = [fixturePins[1]]
        let store = makeStore(
            StubFetchPins(resultsByCategory: [.restaurant: onlyRestaurant]),
            state: loadedState()
        )

        await store.send(.selectCategory(.restaurant)) { $0.category = .restaurant }
        await store.receive(.loaded(onlyRestaurant, for: PinQuery(category: .restaurant))) {
            $0.pins = onlyRestaurant
            $0.locations = locations(onlyRestaurant)
        }
        store.finish()
    }

    @Test("L2 — '전체' 로 되돌리면 다시 다 보인다")
    func selectCategory_backToAll() async {
        let store = makeStore(state: loadedState(pins: [fixturePins[1]], category: .restaurant))

        await store.send(.selectCategory(.all)) { $0.category = .all }
        await store.receive(.loaded(fixturePins, for: PinQuery())) {
            $0.pins = fixturePins
            $0.locations = locations()
        }
        store.finish()
    }

    @Test("L1 — 같은 칩을 다시 고르면 요청을 내지 않는다")
    func selectCategory_sameValueDoesNotRefetch() async {
        let store = makeStore(state: loadedState(category: .cafe))
        await store.send(.selectCategory(.cafe))
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

    // 004-1 ② 2-1 — 헤더 아바타 옆 `+`. 표시 모델이 아니라 도메인 방을 실어 보내야 시트가
    // 참여자 닉네임과 방 색을 쓸 수 있다.
    @Test("L1 — tapAddMember 는 그 방을 실어 친구 초대로 navigate 한다")
    func tapAddMember() async {
        let store = makeStore(state: loadedState())
        await store.send(.tapAddMember)
        store.receiveNavigation(.inviteFriends(fixtureRoom))
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
        let target = locations()[0]
        await store.send(.tapShare(target))
        store.receiveNavigation(.shareLocation(target))
        store.finish()
    }

    // MARK: - 거리순 (004-1 ⑥ "내 기준 3km반경 내에 있는 게시물 노출")

    @Test("L2 — 거리순은 좌표를 받은 뒤에야 선다. 3km 밖은 빠지고 가까운 순으로 세워진다")
    func selectSort_distance() async {
        // 반경 안에서 가까운 순 — 서버가 골라 준 결과다(3km 판정도 서버 몫이라 여기서 재지 않는다).
        let nearby = [fixturePins[2], fixturePins[1]]
        let store = makeStore(
            StubFetchPins(resultsBySort: [.distance: nearby]),
            state: loadedState()
        )

        // 좌표가 서기 전에는 sort 를 건드리지 않는다 — 좌표 없이 `sort=distance` 를 보내면
        // 서버가 400 으로 거절한다.
        await store.send(.selectSort(.distance)) { $0.isLocating = true }
        #expect(store.currentState.sort == .all)

        await store.receive(.locationResolved(.coordinate(fixtureOrigin))) {
            $0.isLocating = false
            $0.myCoordinate = fixtureOrigin
            $0.sort = .distance
        }
        // 좌표를 얻은 뒤에야 거리순 조회가 나간다.
        await store.receive(.loaded(nearby, for: PinQuery(sort: .distance))) {
            $0.pins = nearby
            $0.locations = locations(nearby)
        }

        #expect(store.currentState.locations.map(\.id) == nearby.map(\.id.value))
        store.finish()
    }

    @Test("L2 — 위치 권한이 거부되면 정렬은 고르기 전 값 그대로다. 목록도 손대지 않는다")
    func selectSort_distance_permissionDenied() async {
        let store = makeStore(
            currentLocation: StubCurrentLocation(result: .permissionDenied),
            state: loadedState()
        )

        await store.send(.selectSort(.distance)) { $0.isLocating = true }
        await store.receive(.locationResolved(.permissionDenied)) { $0.isLocating = false }

        #expect(store.currentState.sort == .all)
        #expect(store.currentState.myCoordinate == nil)
        #expect(store.currentState.locations == locations())
        store.finish()
    }

    @Test("L2 — 권한은 있는데 측위에 실패해도 마찬가지다")
    func selectSort_distance_unavailable() async {
        let store = makeStore(
            currentLocation: StubCurrentLocation(result: .unavailable),
            state: loadedState()
        )

        await store.send(.selectSort(.distance)) { $0.isLocating = true }
        await store.receive(.locationResolved(.unavailable)) { $0.isLocating = false }

        #expect(store.currentState.sort == .all)
        #expect(store.currentState.locations == locations())
        store.finish()
    }

    @Test("L2 — 좌표를 이미 받아 뒀으면 다시 묻지 않고 곧장 조회한다")
    func selectSort_distance_reusesCoordinate() async {
        let nearby = [fixturePins[2], fixturePins[1]]
        var state = loadedState()
        state.myCoordinate = fixtureOrigin
        let store = makeStore(StubFetchPins(resultsBySort: [.distance: nearby]), state: state)

        await store.send(.selectSort(.distance)) { $0.sort = .distance }
        await store.receive(.loaded(nearby, for: PinQuery(sort: .distance))) {
            $0.pins = nearby
            $0.locations = locations(nearby)
        }

        store.finish()   // 위치 요청이 또 나갔다면 미처리 effect 로 여기서 걸린다
    }

    @Test("L1 — 좌표를 기다리는 중에 또 누르면 요청을 두 번 보내지 않는다")
    func selectSort_distance_ignoresSecondTap() async {
        var state = loadedState()
        state.isLocating = true
        let store = makeStore(state: state)

        await store.send(.selectSort(.distance))

        store.finish()   // 두 번째 요청이 나갔다면 미처리 effect 로 여기서 걸린다
    }

    @Test("L2 — 기다리는 사이 다른 정렬을 고르면 늦게 온 좌표가 그 선택을 뒤집지 않는다")
    func locationResolved_doesNotOverrideNewerSort() async {
        let store = makeStore(state: loadedState())

        await store.send(.selectSort(.distance)) { $0.isLocating = true }
        await store.send(.selectSort(.latest)) {
            $0.isLocating = false
            $0.sort = .latest
        }
        await store.receive(.loaded(fixturePins, for: PinQuery(sort: .latest)))
        await store.receive(.locationResolved(.coordinate(fixtureOrigin)))

        #expect(store.currentState.sort == .latest)
        #expect(store.currentState.myCoordinate == nil)
        store.finish()
    }

    // 지우고 나서 다시 조회하지 않는다 — 남은 핀의 순서는 이미 서버가 정해 준 그 순서다.
    @Test("L1 — 거리순으로 보는 중에 장소를 지워도 정렬 기준과 남은 순서가 그대로다")
    func deleted_keepsServerOrder() async {
        let nearby = [fixturePins[2], fixturePins[1]]
        var state = loadedState(pins: nearby, sort: .distance)
        state.myCoordinate = fixtureOrigin
        let store = makeStore(state: state)

        await store.send(.deleted(fixturePins[2].id)) {
            $0.pins = [fixturePins[1]]
            $0.locations = [RoomDetailLocation(from: fixturePins[1])]
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }

        #expect(store.currentState.sort == .distance)
        store.finish()   // 재조회가 나갔다면 미처리 effect 로 여기서 걸린다
    }

    // MARK: - 장소 삭제 (004-1 ⑧ / 004-1-3-1)

    @Test("L1 — 케밥의 '장소 삭제' 는 확인 다이얼로그만 연다. 되돌릴 수 없는 조작이라 즉시 지우지 않는다")
    func tapDeleteLocation_opensDialog() async {
        let store = makeStore(state: loadedState())

        await store.send(.tapDeleteLocation(fixturePins[1].id.value)) {
            $0.deletion = RoomDetailDeletion(locationID: fixturePins[1].id.value)
        }

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations())
        store.finish()
    }

    @Test("L1 — 취소하면 다이얼로그만 닫히고 목록도 방 장소 수도 그대로다")
    func cancelDelete_changesNothingElse() async {
        let store = makeStore(state: deletingState(1))

        await store.send(.cancelDelete) { $0.deletion = nil }

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations())
        #expect(store.currentState.room.locationCountText == "3개")
        store.finish()
    }

    @Test("L2 — 확인하면 그 장소가 원본·표시 목록에서 빠지고 방 장소 수도 하나 준다")
    func confirmDelete_removesLocationAndDecrementsCount() async {
        let store = makeStore(state: deletingState(1))
        let remaining = [fixturePins[0], fixturePins[2]]

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleted(fixturePins[1].id)) {
            $0.deletion = nil
            $0.pins = remaining
            $0.locations = remaining.map(RoomDetailLocation.init(from:))
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }

        #expect(store.currentState.room.locationCountText == "2개")
        store.finish()
    }

    @Test("L2 — 삭제에 실패하면 목록이 그대로 남고 다이얼로그의 진행 상태가 풀린다")
    func confirmDelete_failureKeepsList() async {
        let store = makeStore(deletePin: StubDeletePin(error: .unknown), state: deletingState(1))

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleteFailed(.unknown)) { $0.deletion = nil }

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations())
        #expect(store.currentState.room.locationCountText == "3개")
        store.finish()
    }

    // 카테고리를 서버가 거르므로 `pins` 자체가 그 칩의 목록이다 — 지운 뒤 재조회 없이 칩 선택이 남는다.
    @Test("L2 — 업종 칩으로 걸러진 상태에서 지워도 칩 선택이 유지된다")
    func confirmDelete_keepsCategorySelection() async {
        let cafePins = [fixturePins[0], fixturePins[2]]
        let store = makeStore(state: deletingState(0, pins: cafePins, category: .cafe))

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleted(fixturePins[0].id)) {
            $0.deletion = nil
            $0.pins = [fixturePins[2]]
            $0.locations = [RoomDetailLocation(from: fixturePins[2])]
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }

        #expect(store.currentState.category == .cafe)
        store.finish()   // 재조회가 나갔다면 미처리 effect 로 여기서 걸린다
    }

    // 칩이 고정 3종이라 되돌릴 곳이 없다 — 고른 칩을 그대로 두고 목록만 빈다(스펙 EC-003:
    // "해당 카테고리 필터 적용 상태에서 장소 목록이 빈 상태로 표시된다").
    @Test("L2 — 고른 업종의 마지막 장소를 지우면 선택은 남고 목록만 빈다")
    func confirmDelete_keepsCategoryWhenItEmpties() async {
        let store = makeStore(state: deletingState(1, pins: [fixturePins[1]], category: .restaurant))

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleted(fixturePins[1].id)) {
            $0.deletion = nil
            $0.pins = []
            $0.locations = []
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }

        #expect(store.currentState.category == .restaurant)
        store.finish()
    }

    @Test("L1 — 이미 보낸 삭제 요청이 있으면 확인이 다시 들어와도 요청하지 않는다")
    func confirmDelete_ignoresSecondConfirm() async {
        var state = deletingState(1)
        state.deletion?.isSubmitting = true
        let store = makeStore(state: state)

        await store.send(.confirmDelete)

        store.finish()   // 두 번째 요청이 나갔다면 미처리 effect 로 여기서 걸린다
    }

    @Test("L1 — 이미 빠진 장소로 deleted 가 또 들어와도 방 장소 수를 두 번 줄이지 않는다")
    func deleted_ignoresUnknownPin() async {
        let store = makeStore(state: loadedState())

        await store.send(.deleted(PinID("없는-핀")))

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.room.locationCountText == "3개")
        store.finish()
    }

    // MARK: - 헤더 케밥 드롭다운 (004-1 ② 2-2 / 004-5)

    @Test("L2 — 신원이 방 주인과 같으면 방장으로 판정한다")
    func currentMember_owner() async {
        let store = makeStore()

        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(StubCurrentMember.owner)) {
            $0.isOwner = true
            $0.isLoadingCurrentMember = false
        }
        store.finish()
    }

    @Test("L2 — 방 주인이 아니면 방장이 아니다")
    func currentMember_member() async {
        let store = makeStore(currentMember: StubCurrentMember(result: .success(StubCurrentMember.member)))

        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(StubCurrentMember.member)) {
            $0.isLoadingCurrentMember = false
        }
        #expect(store.currentState.isOwner == false)
        store.finish()
    }

    @Test("L2 — 신원 조회에 실패해도 방장이 되지 않는다. 오류 UI 도 띄우지 않는다")
    func currentMember_failure() async {
        let store = makeStore(currentMember: StubCurrentMember(result: .failure(.unknown)))

        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoadFailed(.unknown)) { $0.isLoadingCurrentMember = false }
        #expect(store.currentState.isOwner == false)
        store.finish()
    }

    @Test("L2 — 조회가 진행 중이면 다시 요청하지 않는다")
    func loadCurrentMember_ignoresSecondRequest() async {
        var state = loadedState()
        state.isLoadingCurrentMember = true
        let store = makeStore(state: state)

        await store.send(.loadCurrentMember)

        store.finish()   // 두 번째 요청이 나갔다면 미처리 effect 로 여기서 걸린다
    }

    @Test("L1 — 케밥은 눌러서 열고 다시 눌러서 닫는다")
    func tapMore_toggles() async {
        let store = makeStore(state: loadedState())

        await store.send(.tapMore) { $0.isMoreMenuPresented = true }
        await store.send(.tapMore) { $0.isMoreMenuPresented = false }
        store.finish()
    }

    @Test("L1 — 바깥 탭·단계 전환은 dismissMoreMenu 로 닫는다")
    func dismissMoreMenu() async {
        var state = loadedState()
        state.isMoreMenuPresented = true
        let store = makeStore(state: state)

        await store.send(.dismissMoreMenu) { $0.isMoreMenuPresented = false }
        store.finish()
    }

    @Test("L1 — 방장이 '방 편집' 을 고르면 메뉴가 닫히고 editRoom 으로 navigate 한다")
    func selectMoreMenuItem_editRoom_owner() async {
        var state = loadedState()
        state.isOwner = true
        state.isMoreMenuPresented = true
        let store = makeStore(state: state)

        await store.send(.selectMoreMenuItem(.editRoom)) { $0.isMoreMenuPresented = false }

        store.receiveNavigation(.editRoom(fixtureRoom))
        store.finish()
    }

    @Test("L1 — 방장이 아니면 '방 편집' 이 들어와도 navigate 하지 않는다. 노출 판정을 뷰에만 맡기지 않는다")
    func selectMoreMenuItem_editRoom_member() async {
        var state = loadedState()
        state.isMoreMenuPresented = true
        let store = makeStore(state: state)

        await store.send(.selectMoreMenuItem(.editRoom)) { $0.isMoreMenuPresented = false }

        store.finish()   // navigate 가 나갔다면 미처리 nav 로 여기서 걸린다
    }

    @Test("L1 — '방 나가기' 는 방장이 아니어도 leaveRoom 으로 navigate 한다")
    func selectMoreMenuItem_leaveRoom() async {
        var state = loadedState()
        state.isMoreMenuPresented = true
        let store = makeStore(state: state)

        await store.send(.selectMoreMenuItem(.leaveRoom)) { $0.isMoreMenuPresented = false }

        store.receiveNavigation(.leaveRoom(fixtureRoom))
        store.finish()
    }
}
