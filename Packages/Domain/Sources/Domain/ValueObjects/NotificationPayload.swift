import Foundation

/// 알림 유형별로 화면이 실제로 그리는 값.
/// [Convention] .claude/docs/clean-architecture.md — Value Object: 값으로 동등성 비교, let 불변, 프레임워크 비의존
///
/// 문구를 만들지 않는다 — "이미 저장해둔 곳이에요" 같은 유형 문구는 화면의 몫이고,
/// 여기 담기는 것은 대상 이름처럼 유형마다 달라지는 값뿐이다.
///
/// **필수와 선택을 가르는 기준은 "이번 사이클이 실제로 그리는가" 다.** 대상 이름은 없으면 셀이
/// 빈 문구로 그려지므로 필수고, 식별자·이미지는 없어도 행이 그려지므로 선택이다 — 아무도 읽지 않는
/// 값 때문에 알림이 목록에서 사라지면 안 된다.
///
/// `NotificationType` 과 조합이 어긋난 값을 타입이 막지는 못한다. 조합을 만드는 규칙은
/// `NotificationDTO` 의 대응표 한 곳이며, 그 규칙은 테스트가 강제한다.
public enum NotificationPayload: Equatable, Sendable {
    /// 장소 하나를 가리키는 알림(중복 저장·위치 리마인드·코멘트 리마인드).
    /// `imageURL` 은 장소 대표 이미지 — 없으면 화면이 기본 아이콘 썸네일로 그린다(FR-012).
    /// `placeID` 는 장소 상세로 가는 데 쓰이며, 그 이동은 다음 사이클 몫이라 아직 읽는 곳이 없다.
    /// 도착지 **방**은 알림이 정하지 않는다 — 장소마다 유지되는 현재 표시 기준 방이 정한다(FR-022).
    case place(name: String, imageURL: URL?, placeID: String?)
    /// 저장 오류. 실어 나를 값이 없다 — 유형 문구도 대상 이름도 고정이다(FR-004).
    case saveError
    /// 공동방을 가리키는 알림(참가 2종). `participantName` 은 "누가 들어왔다" 형태에만 있다.
    case room(name: String, roomID: String?, participantName: String?)
    /// 유형은 알지만 그 유형이 요구하는 값을 뽑지 못했을 때. `.none` 은 `Optional` 과 헷갈려 피한다.
    case unresolved
}
