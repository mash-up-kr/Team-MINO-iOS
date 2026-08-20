import Testing
import Domain
import RoomCreationUI
@testable import FeatureArchive

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubArchiveDeps: ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
}

@MainActor
struct ArchiveCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ArchiveCoordinator(deps: StubArchiveDeps()).path.isEmpty)
    }

    @Test("goToCreateRoom 은 방 만들기 화면을 push 하고 탭바를 감춘다")
    func handleGoToCreateRoom_pushes() {
        let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())

        coordinator.handle(RoomListNav.goToCreateRoom)

        #expect(coordinator.path == [.createRoom])
        #expect(coordinator.isFullBleedContentPresented)
    }

    @Test("방 만들기의 확정·취소·건너뛰기는 모두 방 리스트로 pop 한다")
    func handleRoomFormNav_popsToRoomList() {
        for nav: RoomFormNav in [.didSubmit, .didCancel, .didSkip] {
            let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())
            coordinator.handle(RoomListNav.goToCreateRoom)

            coordinator.handle(nav)

            #expect(coordinator.path.isEmpty)
            #expect(!coordinator.isFullBleedContentPresented)
        }
    }

    @Test("배선 — RoomForm Store 의 저장 확인이 path 에 반영된다")
    func roomFormStore_isWiredToPath() async {
        let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())
        coordinator.handle(RoomListNav.goToCreateRoom)

        let store = coordinator.makeRoomFormStore()
        store.send(.roomNameChanged("민호야 잘하자"))   // reduce 가 확정 조건을 가드하므로 이름을 먼저 넣는다
        store.send(.tapSubmit)                        // 확인 다이얼로그를 띄우기만 한다
        store.send(.confirmSubmit)

        await waitUntil { coordinator.path.isEmpty }
        #expect(coordinator.path.isEmpty)
    }
}

/// 조건이 참이 될 때까지 짧게 폴링한다(상한 있음 — 무한 hang 금지).
@MainActor
private func waitUntil(_ condition: () -> Bool, limit: Int = 100) async {
    for _ in 0..<limit {
        if condition() { return }
        await Task.yield()
    }
}
