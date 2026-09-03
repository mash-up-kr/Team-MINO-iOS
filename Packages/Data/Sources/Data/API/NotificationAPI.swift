import Foundation
import Networking

/// 알림(notification) 엔드포인트. 경로가 Repository 메서드 안에 흩어지지 않게 여기 모은다.
enum NotificationAPI {
    private static let base = "api/v1/notifications"

    /// 받은 알림 목록. 페이지네이션을 쓰므로 호출부가 `.paged(page:pageSize:)` 를 붙여
    /// `requestPage` 로 보낸다 — 그 짝은 타입이 강제한다(`PagedEndpoint`).
    ///
    /// 읽음 상태가 없어 필터 파라미터도 없다(스펙 §2.3).
    static func list() -> Endpoint<[NotificationDTO]> {
        Endpoint(path: base)
    }
}
