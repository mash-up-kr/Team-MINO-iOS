import Domain
import Foundation
import Networking

/// `NotificationRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct NotificationRepositoryImpl: NotificationRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func notifications() async throws -> Domain.Page<AppNotification> {
        try await notifications(.first(pageSize: PageRequest.defaultPageSize))
    }

    // `Page` 는 Domain 과 Networking 양쪽에 있어 한정자 없이는 모호하다 — 경계를 넘나드는 파일에서는
    // 어느 쪽 Page 인지 이름으로 드러낸다.
    public func notifications(_ request: PageRequest) async throws -> Domain.Page<AppNotification> {
        do {
            let page = try await client.requestPage(
                NotificationAPI.list().paged(page: request.page, pageSize: request.pageSize)
            )
            // 항목 매핑은 던지지 않는다 — 모르는 유형 한 건이 페이지 전체를 실패시키지 않게
            // `NotificationDTO.toDomain()` 이 `.unknown` 으로 흡수한다(그 주석 참조).
            return page.toDomain(request: request) { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    /// **케이스가 아니라 `statusCode` 로 분기한다**(`RoomRepositoryImpl` 과 같은 이유).
    ///
    /// 서버가 `pagination` 을 빠뜨리면 `requestPage` 가 `.decodingFailed` 를 던진다 —
    /// `statusCode` 가 없어 `default` 로 떨어지고 로그가 남는다. 계약 위반을 조용히 삼키지 않는다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        default:
            error.logUntranslated()
            return DomainError.notificationsFetchFailed
        }
    }
}
