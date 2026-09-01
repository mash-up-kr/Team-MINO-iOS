import Foundation

/// 알림 셀을 눌렀을 때 가는 곳. **식별자만 든다** — 표시값은 ``AppNotification`` 이 서버 값 그대로 갖는다.
///
/// 도착지 **방**을 알림이 정하지 않는다는 점에 주의한다(FR-022): 장소 알림의 payload 에는 방 id 가
/// 없고, 열 방은 그 핀이 속한 방(`Pin.roomID`)이 정한다. payload 에 방 id 가 없는 것이 정상이다.
public enum NotificationDestination: Equatable, Sendable {
    /// 장소(핀) 상세. 서버 `payload.placeId` 는 **핀 id 와 같은 값**이다(팀 확인) —
    /// 이름은 place 지만 `GET /pins/{pinId}` 에 그대로 넣는다.
    case place(pinID: PinID)
    case room(roomID: String)
    /// 저장 오류 안내 화면. 알림 탭 안에서 push 하므로 식별자가 필요 없다(EC-013).
    case saveError
    /// 유형은 알지만 이동에 쓸 식별자를 얻지 못했을 때. 셀은 그리되 탭해도 아무 일도 하지 않는다.
    case unresolved
}
