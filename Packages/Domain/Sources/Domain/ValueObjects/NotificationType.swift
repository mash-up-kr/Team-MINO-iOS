/// 알림의 유형. 서버 `type` enum 6종에 대응한다.
///
/// **라우팅에는 쓰지 않는다** — 그건 ``NotificationDestination`` 이 맡는다. 이 타입이 남아 있는 건
/// 모르는 유형을 목록에서 걸러 내기 위해서다. 그래서 `.unknown` 인 알림의 destination 은 반드시
/// `.unresolved` 여야 한다(둘이 어긋나면 걸러지지 않은 알림이 엉뚱한 곳으로 간다) —
/// 그 불변식은 `NotificationDTO` 의 매핑과 그 테스트가 지킨다.
/// [Convention] .claude/docs/clean-architecture.md — Entity·VO 는 비즈니스 의미를 담는 이름을 쓴다(API 필드명 금지)
///
/// `RoomType` 과 달리 String rawValue 를 쓰지 않는다 — 알 수 없는 값의 원문을 보존해야 하는데
/// 연관값과 `RawRepresentable` 이 공존할 수 없기 때문이다. 그래서 **서버 문자열과의 대응표는
/// 통째로 Data 계층의 `NotificationDTO` 에 있다.**
public enum NotificationType: Equatable, Sendable {
    /// 같은 장소를 이미 저장해 둔 방에 다시 저장했을 때.
    case duplicateSave
    /// 조건에 맞지 않는 게시글이거나 알 수 없는 오류로 저장이 실패했을 때.
    case saveError
    /// 현재 위치 반경 안에 저장해 둔 장소가 있을 때. 반경 안에 여럿이면 목록에는 장소마다 한 건씩 들어간다
    /// — 여러 건을 묶은 대표 알림은 앱 밖으로만 나가고 목록의 유형이 아니다(FR-019).
    case nearbyReminder
    /// 자신이 속한 방들의 장소 중 코멘트가 가장 많은 곳을 다시 알릴 때.
    case commentReminder
    /// 속한 방에 새 멤버가 들어왔을 때(방 소속 전원에게).
    case memberJoined
    /// 자신이 새 멤버로 방에 참가했을 때(본인에게만).
    case roomJoined
    /// 서버가 보낸 유형을 모를 때. 서버에 유형이 늘었는데 앱이 아직 모르는 상황이고,
    /// 원문이 유일한 진단 정보라 버리지 않고 실어 나른다.
    case unknown(raw: String)
}
