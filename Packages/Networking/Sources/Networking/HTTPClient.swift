import Foundation

/// HTTP 통신 추상. 구현체는 Alamofire 등 인프라에 의존하지만,
/// **이 프로토콜 밖으로 라이브러리 타입이 새지 않는다.**
///
/// envelope(`{"data": …}`)은 구현체가 벗긴다 — 호출부는 알맹이만 받는다.
public protocol HTTPClient: Sendable {
    func request<T>(_ endpoint: Endpoint<T>) async throws -> T

    /// 페이지네이션 요청 전용. `pagination` 은 `data` 의 형제라서 `request` 로는 잡히지 않는다.
    /// `paged(page:pageSize:)` 가 만든 `PagedEndpoint` 만 받으므로 짝이 어긋날 수 없다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Page<Element>
}
