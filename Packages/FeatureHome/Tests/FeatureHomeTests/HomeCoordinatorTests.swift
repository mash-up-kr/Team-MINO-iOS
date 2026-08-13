import Domain
import RoomCreationUI
import Testing
@testable import FeatureHome

private struct StubDeps: HomeDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
}

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

@MainActor
struct HomeCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(HomeCoordinator(deps: StubDeps()).path.isEmpty)
    }

    @Test("goToCreateRoom 은 방 만들기 화면을 push 한다")
    func handleGoToCreateRoom_pushes() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.goToCreateRoom)
        #expect(coordinator.path == [.createRoom])
    }

    @Test("방 만들기에서 didCreateRoom 은 홈으로 pop 한다")
    func handleCreateRoomNav_popsHome() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.goToCreateRoom)
        coordinator.handle(CreateRoomNav.didCreateRoom)
        #expect(coordinator.path.isEmpty)
    }
}
