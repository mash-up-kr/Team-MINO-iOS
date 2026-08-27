import Domain
import Foundation
import RoomCreationUI
import Testing
@testable import FeatureHome

private struct StubDeps: HomeDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchPins: FetchPinsUseCase = StubFetchPins()
    var lastViewedRoom: LastViewedRoomUseCase = StubLastViewedRoom()
    var homeGuide: HomeGuideUseCase = StubHomeGuide()
    var savePin: SavePinToRoomsUseCase = StubSavePin()
    var createRoom: CreateRoomUseCase = StubCreateRoom()
}

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubFetchPins: FetchPinsUseCase {
    func execute(rooms: [Room], filter: PinFilter) async throws -> [Pin] { [] }
    func execute(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] { [] }
}

private struct StubLastViewedRoom: LastViewedRoomUseCase {
    func load() async -> String? { nil }
    func save(roomID: String) async {}
}

private struct StubHomeGuide: HomeGuideUseCase {
    func hasSeen() async -> Bool { true }
    func markSeen() async {}
}

private struct StubSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws {}
}

private struct StubCreateRoom: CreateRoomUseCase {
    func execute(name: String, description: String?, color: RoomColor) async throws -> Room {
        Room(
            id: "new", type: .shared, name: name, description: description, color: color,
            ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0, memberCount: 1, users: []
        )
    }
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

    @Test("방 만들기에서 didSubmit 은 홈으로 pop 한다")
    func handleRoomFormNav_popsHome() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.goToCreateRoom)
        coordinator.handle(RoomFormNav.didSubmit(roomId: "room-1"))
        #expect(coordinator.path.isEmpty)
    }
}
