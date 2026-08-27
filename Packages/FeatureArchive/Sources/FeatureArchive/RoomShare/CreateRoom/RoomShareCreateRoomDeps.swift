import Domain

/// 공유 시트 위에서 여는 공동방 만들기 자식 flow 의 좁은 의존.
///
/// ``ArchiveDeps`` 가 이 프로토콜을 확장(refine)한다 — 자식은 `createRoom` 하나만 보고
/// (방 목록·핀·공유 저장 UseCase 는 안 보인다), 조립부(App)는 지금처럼 `ArchiveDeps` 하나만
/// 준수하면 된다.
///
/// > 별도 factory 프로토콜은 두지 않는다. `.claude/docs/mvi-coordinator-di-extensions.md`
/// > "deps factory" 의 목적은 *부모가 자식 의존을 모르게* 하는 것인데, 여기서 자식 의존은
/// > 부모가 이미 들고 있던 것의 진부분집합이라 가릴 것이 없다.
public protocol RoomShareCreateRoomDeps {
    var createRoom: CreateRoomUseCase { get }
}
