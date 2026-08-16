import Domain

/// HomeCoordinator 가 요구하는 좁은 의존성 묶음.
public protocol HomeDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    var fetchPins: FetchPinsUseCase { get }
    var lastViewedRoom: LastViewedRoomUseCase { get }
}
