import Foundation

/// 고유 식별자(id)로 구분되는 도메인 Entity — 사용자가 받은 알림 한 건.
/// [Convention] .claude/docs/clean-architecture.md — Entity 는 Codable 을 준수하지 않는다(API 스키마와 결합 방지)
///
/// **읽음 여부를 갖지 않는다** — 알림은 읽힌 것과 읽히지 않은 것으로 나뉘지 않는다(FR-016 · 스펙 §2.3).
/// 서버 응답에는 `readAt` 이 실려 오지만 경계에서 멈추고 여기까지 올라오지 않는다.
///
/// 이름이 `Notification` 이 아닌 이유: `Foundation` 이 같은 이름을 이미 쓴다. Data·Feature 는
/// `Foundation` 과 `Domain` 을 함께 import 하므로 한정자 없이 쓸 수 없게 된다.
public struct AppNotification: Equatable, Identifiable, Sendable {
    public let id: NotificationID
    public let type: NotificationType
    public let payload: NotificationPayload
    public let createdAt: Date

    public init(
        id: NotificationID,
        type: NotificationType,
        payload: NotificationPayload,
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.createdAt = createdAt
    }
}
