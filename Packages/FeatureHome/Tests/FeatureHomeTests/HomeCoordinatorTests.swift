import Domain
import Foundation
import PlaceDetailUI
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
    // 장소 상세(PlaceDetailDeps) 몫 — 라우팅 테스트는 Store 를 만들지 않아 호출되지 않는다.
    var fetchPinDetail: FetchPinDetailUseCase = StubUnused()
    var currentMember: CurrentMemberUseCase = StubUnused()
    var fetchSavedRooms: FetchSavedRoomsUseCase = StubUnused()
    var fetchComments: FetchPinCommentsUseCase = StubUnused()
    var postComment: PostPinCommentUseCase = StubUnused()
    var deleteComment: DeletePinCommentUseCase = StubUnused()
}

/// 이 스위트가 쓰지 않는 장소 상세 유스케이스들. 불리면 값이 아니라 **실패**를 돌려준다 —
/// 조용한 기본값을 주면 나중에 실제로 부르는 경로가 생겨도 테스트가 통과해 버린다.
private struct StubUnused: FetchPinDetailUseCase, CurrentMemberUseCase, FetchSavedRoomsUseCase,
                           FetchPinCommentsUseCase, PostPinCommentUseCase, DeletePinCommentUseCase {
    func execute(pinID: PinID) async throws -> PinDetail { throw DomainError.unknown }
    func execute() async throws -> MemberProfile { throw DomainError.unknown }
    func execute(pin: Pin) async throws -> [Room] { throw DomainError.unknown }
    func execute(pinID: PinID) async throws -> [PinComment] { throw DomainError.unknown }
    func execute(pinID: PinID, body: String) async throws -> PinComment { throw DomainError.unknown }
    func execute(commentID: PinCommentID) async throws { throw DomainError.unknown }
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
