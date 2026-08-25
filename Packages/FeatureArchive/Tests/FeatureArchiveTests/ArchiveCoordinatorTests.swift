import Foundation
import Testing
import Domain
@testable import FeatureArchive

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubFetchPins: FetchPinsUseCase {
    func execute(roomIDs: [RoomID], filter: PinFilter) async throws -> [Pin] { [] }
    func execute(roomID: RoomID, page: Int, filter: PinFilter) async throws -> [Pin] { [] }
}

private struct StubArchiveDeps: ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchPins: FetchPinsUseCase = StubFetchPins()
}

private let fixtureRoom = Room(
    id: RoomID("r2"), type: .shared, name: "우리 동네 맛집", description: "메모", color: "#FFC06E",
    ownerId: "u1", inviteCode: "C2", createdAt: Date(timeIntervalSince1970: 0),
    pinCount: 3, memberCount: 2, users: []
)

private let fixturePin = Pin(
    id: PinID("p1"), roomID: fixtureRoom.id, category: .worthVisiting,
    title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
    createdAt: Date(timeIntervalSince1970: 0)
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

    @Test("openPlaceDetail 은 고른 핀을 장소 상세 단계로 올린다")
    func openPlaceDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        #expect(coordinator.selectedPin == fixturePin)
    }

    @Test("장소 상세를 닫으면 방 상세 단계로 되돌린다")
    func closePlaceDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        coordinator.handle(PlaceDetailNav.close)
        #expect(coordinator.selectedPin == nil)
        #expect(coordinator.selectedRoom == fixtureRoom)
    }

    @Test("방 상세를 닫으면 열려 있던 장소 상세도 함께 정리한다")
    func closeRoomDetail_clearsPlace() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        coordinator.handle(RoomDetailNav.close)
        #expect(coordinator.selectedPin == nil)
    }

    @Test("장소 상세의 공유도 같은 공유 시트로 넘어간다")
    func sharePlaceDetail() {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(from: fixturePin)
        coordinator.handle(PlaceDetailNav.share(location))
        #expect(coordinator.sharingLocation == location)
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
