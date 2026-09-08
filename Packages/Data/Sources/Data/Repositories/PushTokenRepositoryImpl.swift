import Domain
import Foundation
import Networking

/// `PushTokenRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct PushTokenRepositoryImpl: PushTokenRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func register(token: String) async throws {
        do {
            _ = try await client.request(UserAPI.updatePushToken(UpdatePushTokenRequestDTO(token: token)))
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층.
    ///
    /// 미등록(`USER_NOT_REGISTERED`)도 401 로 오는데 `unauthorizedReason` 이 그걸 `.notRegistered` 로
    /// 가른다 — 온보딩을 마치기 전에 토큰을 올린 실수가 `.unauthorized` 에 섞여 묻히지 않게 한다.
    /// 그 외에는 `.unknown` 이다. 이 실패를 사용자에게 구분해 보여줄 화면이 없어 `DomainError` 케이스를
    /// 미리 만들지 않는다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return error.unauthorizedReason
        default:
            error.logUntranslated()
            return DomainError.unknown
        }
    }
}
