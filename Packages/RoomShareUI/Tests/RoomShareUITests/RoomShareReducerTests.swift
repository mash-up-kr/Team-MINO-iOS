import Domain
import Foundation
import MVITestSupport
import Testing
import RoomShareUI

private func fixtureRoom(_ id: String) -> Room {
    Room(
        id: id, type: .shared, name: "방 \(id)", description: "메모", color: .orange,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 2, memberCount: 1, users: []
    )
}

private struct StubShareTargets: FetchShareTargetsUseCase {
    var targets: [ShareTarget] = []
    var error: DomainError?

    func execute(pinID: PinID) async throws -> [ShareTarget] {
        if let error { throw error }
        return targets
    }
}

/// 저장 스파이 — **어떤 장소를 어느 방들에 저장했는지** 모은다.
/// 고른 방이 실제로 UseCase 까지 도달하는지가 이 화면의 본질이라 인자를 기록한다.
private actor SpySavePin: SavePinToRoomsUseCase {
    private(set) var saved: [(pinID: PinID, roomIDs: Set<String>)] = []

    func execute(pinID: PinID, roomIDs: Set<String>) async throws {
        saved.append((pinID, roomIDs))
    }
}

private struct ThrowingSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws { throw DomainError.unknown }
}

@MainActor
struct RoomShareReducerTests {
    private let pinID = PinID("pin-0")
    private let targets = [
        ShareTarget(room: fixtureRoom("room-0"), alreadySaved: true),
        ShareTarget(room: fixtureRoom("room-1"), alreadySaved: false),
        ShareTarget(room: fixtureRoom("room-2"), alreadySaved: false),
    ]

    private func makeStore(
        targets: FetchShareTargetsUseCase = StubShareTargets(),
        savePin: SavePinToRoomsUseCase = SpySavePin(),
        state: RoomShareState? = nil
    ) -> TestStore<RoomShareState, RoomShareAction, RoomShareNav> {
        TestStore(
            state ?? RoomShareState(pinID: pinID),
            reduce: roomShareReducer(fetchTargets: targets, savePin: savePin)
        )
    }

    /// load 를 마친 뒤의 상태를 손으로 짓는다 — 토글·저장 케이스가 매번 load 를 태우지 않게.
    private func loadedState(
        alreadySaved: Set<String> = ["room-0"],
        selected: Set<String> = [],
        isSaving: Bool = false
    ) -> RoomShareState {
        var selection = RoomShareSelection()
        selected.forEach { selection.toggle($0) }
        return RoomShareState(
            pinID: pinID,
            rooms: targets.map { RoomShareRoom(from: $0.room) },
            alreadySavedRoomIDs: alreadySaved,
            selection: selection,
            isSaving: isSaving
        )
    }

    // MARK: - Load

    @Test("L2 — load 는 방 목록과 이미 저장된 방을 함께 받는다")
    func load_success() async {
        let store = makeStore(targets: StubShareTargets(targets: targets))
        let expectedRooms = targets.map { RoomShareRoom(from: $0.room) }

        await store.send(.load) { $0.isLoading = true }
        await store.receive(.loaded(targets)) {
            $0.isLoading = false
            $0.rooms = expectedRooms
            $0.alreadySavedRoomIDs = ["room-0"]
        }

        store.finish()
    }

    @Test("L2 — load 실패는 로딩을 끄고 오류를 남긴다")
    func load_failure() async {
        let store = makeStore(targets: StubShareTargets(error: .roomsFetchFailed))

        await store.send(.load) { $0.isLoading = true }
        await store.receive(.loadFailed(.roomsFetchFailed)) {
            $0.isLoading = false
            $0.error = .roomsFetchFailed
        }

        store.finish()
    }

    // MARK: - 선택

    @Test("L1 — 방을 고르면 선택에 담기고, 다시 누르면 풀린다")
    func toggleRoom_onOff() async {
        let store = makeStore(state: loadedState())

        await store.send(.toggleRoom("room-1")) { $0.selection.toggle("room-1") }
        #expect(store.currentState.canSubmit)

        await store.send(.toggleRoom("room-1")) { $0.selection.toggle("room-1") }
        #expect(store.currentState.canSubmit == false)

        store.finish()
    }

    @Test("L1 — 이미 저장된 방은 토글해도 선택이 바뀌지 않는다")
    func toggleRoom_ignoresAlreadySaved() async {
        let store = makeStore(state: loadedState(alreadySaved: ["room-0"]))

        await store.send(.toggleRoom("room-0"))   // 상태 변화 없음(expect 생략)

        // 체크로는 보이지만 선택이 아니라 공유 버튼은 꺼진 채다.
        #expect(store.currentState.checkedRoomIDs == ["room-0"])
        #expect(store.currentState.canSubmit == false)
        store.finish()
    }

    @Test("L1 — 저장 중에는 토글을 무시한다")
    func toggleRoom_ignoredWhileSaving() async {
        let store = makeStore(state: loadedState(selected: ["room-1"], isSaving: true))

        await store.send(.toggleRoom("room-2"))   // 상태 변화 없음

        #expect(store.currentState.selection.contains("room-2") == false)
        store.finish()
    }

    // MARK: - 새 방 만들기 (기획 011-1 ③)

    @Test("L1 — 새 방 만들기는 공동방 만들기로 넘긴다")
    func tapCreateRoom_navigates() async {
        let store = makeStore(state: loadedState(selected: ["room-1"]))

        await store.send(.tapCreateRoom)   // 상태 변화 없음 — 시트는 그대로 살아 있다
        store.receiveNavigation(.goToCreateRoom)

        store.finish()
    }

    @Test("L3 — 저장 중에는 새 방 만들기로 나가지 않는다")
    func tapCreateRoom_ignoredWhileSaving() async {
        let store = makeStore(state: loadedState(selected: ["room-1"], isSaving: true))

        await store.send(.tapCreateRoom)   // 상태 변화 없음

        // 미처리 navigation 이 남아 있으면 여기서 실패한다 — 저장이 끝나 시트가 닫히는 자리에
        // 커버가 떠 있으면 안 된다.
        store.finish()
    }

    @Test("L2 — 방을 만들고 돌아오면 목록을 다시 받고, 고르던 선택은 그대로다")
    func createRoomFinished_created_reloadsAndKeepsSelection() async {
        let afterCreate = targets + [ShareTarget(room: fixtureRoom("room-3"), alreadySaved: false)]
        let store = makeStore(
            targets: StubShareTargets(targets: afterCreate),
            state: loadedState(selected: ["room-1"])
        )

        await store.send(.createRoomFinished(.created)) { $0.isLoading = true }
        await store.receive(.loaded(afterCreate)) {
            $0.isLoading = false
            $0.rooms = afterCreate.map { RoomShareRoom(from: $0.room) }
            $0.alreadySavedRoomIDs = ["room-0"]
        }

        // 새 방이 목록에 들어왔다.
        #expect(store.currentState.rooms.map(\.id).contains("room-3"))
        // 이 이슈의 핵심 — 방을 만들러 다녀와도 고르던 체크가 살아 있다.
        #expect(store.currentState.selection.ids == ["room-1"])
        #expect(store.currentState.canSubmit)
        store.finish()
    }

    @Test("L3 — 취소로 돌아오면 목록을 다시 받지 않는다")
    func createRoomFinished_cancelled_doesNotReload() async {
        let store = makeStore(
            targets: StubShareTargets(targets: targets),
            state: loadedState(selected: ["room-1"])
        )

        await store.send(.createRoomFinished(.cancelled))   // 상태 변화 없음

        #expect(store.currentState.selection.ids == ["room-1"])
        // 미처리 effect 가 남아 있으면(= 불필요한 재조회) 여기서 실패한다.
        store.finish()
    }

    // MARK: - 저장

    @Test("L1 — 아무 방도 고르지 않으면 공유하기가 아무 일도 하지 않는다")
    func tapSubmit_ignoredWithoutSelection() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: loadedState())

        await store.send(.tapSubmit)   // 상태 변화 없음 + effect 없음

        #expect(await spy.saved.isEmpty)
        store.finish()
    }

    @Test("L2 — 공유하기는 저장 중 잠금을 켜고, 끝나면 완료를 알린다")
    func tapSubmit_savesAndNavigates() async {
        let store = makeStore(state: loadedState(selected: ["room-1"]))

        await store.send(.tapSubmit) { $0.isSaving = true }
        await store.receive(.saveFinished) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        store.finish()
    }

    @Test("L2 — 저장 UseCase 가 고른 장소·방을 그대로 받는다")
    func tapSubmit_passesSelectedRooms() async {
        let spy = SpySavePin()
        let store = makeStore(savePin: spy, state: loadedState(selected: ["room-1", "room-2"]))

        await store.send(.tapSubmit) { $0.isSaving = true }
        await store.receive(.saveFinished) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        let saved = await spy.saved
        #expect(saved.count == 1)
        #expect(saved.first?.pinID == pinID)
        // 이미 저장된 room-0 은 섞이지 않는다 — 고른 방만 간다.
        #expect(saved.first?.roomIDs == ["room-1", "room-2"])
        store.finish()
    }

    @Test("L3 — 저장 실패는 잠금을 풀고 완료를 알리지 않는다")
    func tapSubmit_failure() async {
        let store = makeStore(savePin: ThrowingSavePin(), state: loadedState(selected: ["room-1"]))

        await store.send(.tapSubmit) { $0.isSaving = true }
        await store.receive(.saveFailed(.unknown)) {
            $0.isSaving = false
            $0.error = .unknown
        }

        // 다시 시도할 수 있다.
        #expect(store.currentState.canSubmit)
        // 미처리 navigation 이 남아 있으면 여기서 실패한다 — 실패에는 완료 토스트가 뜨면 안 된다.
        store.finish()
    }
}
