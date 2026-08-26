import Domain
import Foundation
import Logging
import Networking

/// `ProfileRepository` 의 네트워크 구현. `AppDependencies` 가 공유 `httpClient` 를 넘긴다.
public struct ProfileRepositoryImpl: ProfileRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func register(nickname: String, avatarIndex: Int) async throws -> Profile {
        let body = RegisterProfileRequestDTO(nickname: nickname, avatar: AvatarDTO(id: avatarIndex))
        return try await send(UserAPI.register(body), fallback: .profileSaveFailed)
    }

    public func me() async throws -> Profile {
        try await send(UserAPI.me(), fallback: .profileFetchFailed)
    }

    public func update(nickname: String?, avatarIndex: Int?) async throws -> Profile {
        let body = UpdateProfileRequestDTO(
            nickname: nickname,
            avatar: avatarIndex.map(AvatarDTO.init(id:))
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
    ///
    /// > ⚠️ 이미 등록된 uid 로 `POST /api/v1/users` 를 다시 부르면 서버가 뭘 주는지 아직 모른다.
    /// > Firebase 익명 세션은 Keychain 에 남아 앱을 지웠다 깔아도 같은 uid 로 돌아오는데
    /// > 온보딩 완료 플래그(UserDefaults)는 사라지므로, 재설치하면 이 경로를 다시 탄다.
    /// > 서버 응답이 확인되면 여기에 "이미 등록됨"을 성공으로 흡수하는 분기가 필요할 수 있다.
    private static func mapToDomain(_ error: NetworkError, fallback: DomainError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 404, 422: return fallback
        default:
            // 번역하지 못했다는 사실은 반드시 남긴다 — 어떤 DomainError 를 추가해야 하는지
            // 알 수 있는 유일한 단서다. 오류는 label(케이스 이름)로만 남긴다 —
            // 통째로 찍으면 서버 원문 message 가 릴리즈 기기 로그에 평문으로 남는다(README §금지).
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return fallback
        }
    }
}
