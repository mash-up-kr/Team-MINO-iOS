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

private struct StubDeletePin: DeletePinUseCase {
    var error: DomainError?

    func execute(pinID: PinID) async throws {
        if let error { throw error }
    }
}

/// `fixtureRoom.ownerId` 가 "u1" 이라 기본값은 **방장 본인**이다.
private struct StubCurrentMember: CurrentMemberUseCase {
    var result: Result<MemberProfile, DomainError> = .success(owner)

    static let owner = MemberProfile(id: MemberID("u1"), nickname: "방장", avatarID: 0)
    static let member = MemberProfile(id: MemberID("u9"), nickname: "멤버", avatarID: 1)

    func execute() async throws -> MemberProfile {
        switch result {
        case .success(let profile): return profile
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct RoomDetailReducerTests {
    private func makeStore(
        _ useCase: FetchPinsUseCase = StubFetchPins(),
        deletePin: DeletePinUseCase = StubDeletePin(),
        currentMember: CurrentMemberUseCase = StubCurrentMember(),
        state: RoomDetailState = RoomDetailState(room: RoomDetailRoom(from: fixtureRoom))
    ) -> TestStore<RoomDetailState, RoomDetailAction, RoomDetailNav> {
        TestStore(
            state,
            reduce: roomDetailReducer(
                useCase: useCase,
                deletePin: deletePin,
                fetchCurrentMember: currentMember,
                room: fixtureRoom,
                now: { fixtureNow }
            )
        )
    }

    /// 삭제 확인 다이얼로그가 열린 상태 — 케밥에서 "장소 삭제" 를 누른 직후.
    private func deletingState(_ index: Int, category: String = RoomDetailCategoryList.all) -> RoomDetailState {
        var state = loadedState()
        state.category = category
        state.locations = RoomDetailCategoryList.filter(fixturePins, by: category)
            .map(RoomDetailLocation.init(from:))
        state.deletion = RoomDetailDeletion(locationID: fixturePins[index].id.value)
        return state
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

    // MARK: - 장소 삭제 (004-1 ⑧ / 004-1-3-1)

    @Test("L1 — 케밥의 '장소 삭제' 는 확인 다이얼로그만 연다. 되돌릴 수 없는 조작이라 즉시 지우지 않는다")
    func tapDeleteLocation_opensDialog() async {
        let store = makeStore(state: loadedState())

        await store.send(.tapDeleteLocation(fixturePins[1].id.value)) {
            $0.deletion = RoomDetailDeletion(locationID: fixturePins[1].id.value)
        }

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations(.all))
        store.finish()
    }

    @Test("L1 — 취소하면 다이얼로그만 닫히고 목록도 방 장소 수도 그대로다")
    func cancelDelete_changesNothingElse() async {
        let store = makeStore(state: deletingState(1))

        await store.send(.cancelDelete) { $0.deletion = nil }

        #expect(store.currentState.pins == fixturePins)
        #expect(store.currentState.locations == locations(.all))
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
            $0.categories = ["전체", "카페"]   // 음식점은 그 장소 하나뿐이었다
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
        #expect(store.currentState.locations == locations(.all))
        #expect(store.currentState.room.locationCountText == "3개")
        store.finish()
    }

    @Test("L2 — 업종 칩으로 걸러진 상태에서 지워도 원본과 표시 목록이 어긋나지 않는다")
    func confirmDelete_keepsFilteredListInSync() async {
        // "카페"(p0·p20) 로 걸러 둔 채 p0 를 지운다 — 표시 목록에는 p20 만, 원본에는 음식점도 남아야 한다.
        let store = makeStore(state: deletingState(0, category: "카페"))
        let remaining = [fixturePins[1], fixturePins[2]]

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleted(fixturePins[0].id)) {
            $0.deletion = nil
            $0.pins = remaining
            $0.categories = ["전체", "음식점", "카페"]   // 남은 핀의 등장 순서
            $0.locations = [RoomDetailLocation(from: fixturePins[2])]
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }

        #expect(store.currentState.category == "카페")   // 아직 남아 있는 업종이라 선택을 유지한다
        store.finish()
    }

    @Test("L2 — 고른 업종의 마지막 장소를 지우면 빈 목록 대신 '전체' 로 되돌아간다")
    func confirmDelete_resetsCategoryWhenItDisappears() async {
        let store = makeStore(state: deletingState(1, category: "음식점"))
        let remaining = [fixturePins[0], fixturePins[2]]

        await store.send(.confirmDelete) { $0.deletion?.isSubmitting = true }
        await store.receive(.deleted(fixturePins[1].id)) {
            $0.deletion = nil
            $0.pins = remaining
            $0.category = "전체"
            $0.categories = ["전체", "카페"]
            $0.locations = remaining.map(RoomDetailLocation.init(from:))
            $0.room = RoomDetailRoom(from: fixtureRoom).removingOneLocation()
        }
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
