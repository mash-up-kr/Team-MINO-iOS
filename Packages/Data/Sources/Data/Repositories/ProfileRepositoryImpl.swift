import Domain
import Foundation
import Networking

/// `ProfileRepository` 의 네트워크 구현. `AppDependencies` 가 공유 `httpClient` 를 넘긴다.
public struct ProfileRepositoryImpl: ProfileRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func register(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        let body = RegisterProfileRequestDTO(nickname: nickname, avatar: AvatarRequestDTO(color: avatarColor.rawValue))
        return try await send(UserAPI.register(body), fallback: .profileSaveFailed)
    }

    public func me() async throws -> Profile {
        try await send(UserAPI.me(), fallback: .profileFetchFailed)
    }

    public func update(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        let body = UpdateProfileRequestDTO(
            nickname: nickname,
            avatar: avatarColor.map { AvatarRequestDTO(color: $0.rawValue) }
        )
        return try await send(UserAPI.updateMe(body), fallback: .profileSaveFailed)
    }

    /// 세 메서드가 같은 경계를 지난다 — 오류 번역을 한 곳에 모아 정책이 갈리지 않게 한다.
    private func send(_ endpoint: Endpoint<ProfileDTO>, fallback: DomainError) async throws -> Profile {
        do {
            return try await client.request(endpoint).toDomain()
        } catch let error as NetworkError {
            throw Self.mapToDomain(error, fallback: fallback)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다.** 같은 404 가 본문 모양에 따라
    /// `.notFound` 로도 `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다.
    private static func mapToDomain(_ error: NetworkError, fallback: DomainError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return error.unauthorizedReason
        // 이미 등록된 uid 로 다시 등록했다. 재설치한 사용자가 여기 닿으므로 저장 실패로 뭉개면
        // 원인을 알 수 없는 채 온보딩에 갇힌다 — 화면이 구분해 처리하도록 어휘를 준다.
        case 409: return DomainError.alreadyRegistered
        case 400, 404, 422: return fallback
        default:
            error.logUntranslated()
            return fallback
        }
    }
}
