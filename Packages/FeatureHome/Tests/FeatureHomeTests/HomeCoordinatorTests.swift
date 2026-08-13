import Domain
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

    @Test("goToCreateRoom 은 아직 no-op — path 가 변하지 않는다")
    func handleCreateRoom_noop() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.goToCreateRoom)
        #expect(coordinator.path.isEmpty)
    }
}
