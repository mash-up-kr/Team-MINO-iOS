import Testing
import Domain
@testable import FeatureArchive

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubFetchPins: FetchPinsUseCase {
    func execute(rooms: [Room]) async throws -> [Pin] { [] }
    func execute(room: Room, page: Int) async throws -> [Pin] { [] }
}

private struct StubArchiveDeps: ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchPins: FetchPinsUseCase = StubFetchPins()
}

@MainActor
struct ArchiveCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ArchiveCoordinator(deps: StubArchiveDeps()).path.isEmpty)
    }
}
