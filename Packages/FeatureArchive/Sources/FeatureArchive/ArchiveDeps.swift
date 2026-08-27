import Core
import Domain

/// ArchiveCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수하고,
/// Coordinator 는 자신의 deps 프로토콜만 알면 되므로 결합이 최소화된다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
///
/// 공유 시트에서 여는 공동방 만들기 자식 flow 의 의존(``RoomShareCreateRoomDeps``)을 확장한다 —
/// 자식은 그 좁은 창만 보고, 조립부(App)는 지금처럼 `ArchiveDeps` 하나만 준수하면 된다.
public protocol ArchiveDeps: RoomShareCreateRoomDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    var fetchPins: FetchPinsUseCase { get }
    /// 장소 상세의 "원문보기" 가 쓰는 핀 단독 조회 — 목록(`fetchPins`)에는 출처 링크가 실리지 않는다.
    var fetchPinDetail: FetchPinDetailUseCase { get }
    /// 다른 방에 공유 시트가 그릴 방 목록 — 각 방에 이 장소가 이미 있는지까지 함께.
    var fetchShareTargets: FetchShareTargetsUseCase { get }
    /// 다른 방에 공유 — 고른 방들에 이 장소를 담는다.
    var savePin: SavePinToRoomsUseCase { get }
    /// 공동방 생성 유도 시트를 "나중에 만들래요" 로 미뤄 둔 상태(2주). 서버가 모르는 기기 로컬
    /// 표시 정책이라 UseCase 가 아니라 ``SnoozeSwitch`` 를 그대로 받는다.
    var roomCreationPromptSnooze: SnoozeSwitch { get }
}
