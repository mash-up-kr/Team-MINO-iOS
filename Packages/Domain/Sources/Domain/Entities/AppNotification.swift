import Foundation

/// 고유 식별자(id)로 구분되는 도메인 Entity — 사용자가 받은 알림 한 건.
/// [Convention] .claude/docs/clean-architecture.md — Entity 는 Codable 을 준수하지 않는다(API 스키마와 결합 방지)
///
/// **표시 문구를 앱이 만들지 않는다.** 서버가 `typeLabel` 로 완성해서 주므로 여기서는 그대로 실어 나른다.
/// 유형별 문구 switch 를 앱에 두면 서버가 문구를 바꿀 때마다 앱 배포가 필요해진다.
///
/// **읽음 여부를 갖지 않는다** — 알림은 읽힌 것과 읽히지 않은 것으로 나뉘지 않는다(FR-016 · 스펙 §2.3).
///
/// 이름이 `Notification` 이 아닌 이유: `Foundation` 이 같은 이름을 이미 쓴다. Data·Feature 는
/// `Foundation` 과 `Domain` 을 함께 import 하므로 한정자 없이 쓸 수 없게 된다.
public struct AppNotification: Equatable, Identifiable, Sendable {
    public let id: NotificationID
    /// 라우팅은 ``destination`` 이 맡는다. 이 값이 남아 있는 건 **모르는 유형을 목록에서 걸러 내기
    /// 위해서**이고, 원문(`unknown(raw:)`)이 계약 어긋남의 유일한 진단 정보이기 때문이다.
    public let type: NotificationType
    /// 셀 첫 줄. 서버 `typeLabel`.
    public let title: String
    /// 셀 둘째 줄. 서버 `targetName`.
    public let targetName: String
    public let thumbnailURL: URL?
    public let destination: NotificationDestination
    public let createdAt: Date

    public init(
        id: NotificationID,
        type: NotificationType,
        title: String,
        targetName: String,
        thumbnailURL: URL?,
        destination: NotificationDestination,
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.targetName = targetName
        self.thumbnailURL = thumbnailURL
        self.destination = destination
        self.createdAt = createdAt
    }
}
