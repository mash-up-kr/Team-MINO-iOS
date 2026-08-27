import Domain
import Foundation
import Networking

/// `RoomRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct RoomRepositoryImpl: RoomRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func rooms() async throws -> [Room] {
        do {
            return try await client.request(RoomAPI.list()).map { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다** — 같은 404 가 본문 모양에 따라 `.notFound` 로도
    /// `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        default:
            error.logUntranslated()
            return DomainError.roomsFetchFailed
        }
    }
}
