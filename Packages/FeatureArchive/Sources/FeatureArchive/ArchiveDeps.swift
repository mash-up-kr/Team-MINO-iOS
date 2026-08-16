import Domain

/// ArchiveCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수하고,
/// Coordinator 는 자신의 deps 프로토콜만 알면 되므로 결합이 최소화된다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
public protocol ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    /// 방 상세가 그 방에 저장된 장소를 불러올 때 쓴다.
    var fetchPins: FetchPinsUseCase { get }
}
