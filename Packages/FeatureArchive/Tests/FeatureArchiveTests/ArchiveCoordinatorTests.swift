import Foundation
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

private let fixtureRoom = Room(
    id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: "#FFC06E",
    ownerId: "u1", inviteCode: "C2", createdAt: Date(timeIntervalSince1970: 0),
    pinCount: 3, memberCount: 2, users: []
)

@MainActor
struct ArchiveCoordinatorTests {
    private func makeCoordinator() -> ArchiveCoordinator {
        ArchiveCoordinator(deps: StubArchiveDeps())
    }

    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(makeCoordinator().path.isEmpty)
    }

    @Test("생성 직후에는 방 리스트 단계다")
    func startsOnRoomList() {
        #expect(makeCoordinator().isRoomDetailPresented == false)
    }

    @Test("openRoomDetail 은 고른 방을 방 상세 단계로 올린다")
    func openRoomDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        #expect(coordinator.selectedRoom == fixtureRoom)
        #expect(coordinator.isRoomDetailPresented)
    }

    @Test("close 는 방 리스트 단계로 되돌린다")
    func closeRoomDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.close)
        #expect(coordinator.selectedRoom == nil)
    }

    @Test("shareLocation 은 공유할 장소를 껍데기에 넘긴다")
    func shareLocation() {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(
            id: "p1", name: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            commentCount: 0, photoCount: 1
        )
        coordinator.handle(RoomDetailNav.shareLocation(location))
        #expect(coordinator.sharingLocation == location)
    }
}
