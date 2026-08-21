import Core
import Domain

/// ArchiveCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수하고,
/// Coordinator 는 자신의 deps 프로토콜만 알면 되므로 결합이 최소화된다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
public protocol ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    /// 공동방 생성 유도 시트를 "나중에 만들래요" 로 미뤄 둔 상태(2주). 서버가 모르는 기기 로컬
    /// 표시 정책이라 UseCase 가 아니라 ``SnoozeSwitch`` 를 그대로 받는다.
    var roomCreationPromptSnooze: SnoozeSwitch { get }
}
