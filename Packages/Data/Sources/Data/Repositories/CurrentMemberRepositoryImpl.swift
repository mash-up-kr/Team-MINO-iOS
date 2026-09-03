import Domain
import Foundation
import Networking

/// `CurrentMemberRepository` 의 실 API 구현 (`GET /api/v1/users/me`).
///
/// ``ProfileRepositoryImpl`` 과 **같은 응답을 다르게 읽는다** — 그쪽은 프로필 화면이 쓰는
/// ``Profile``(닉네임·아바타·가입일), 이쪽은 소유 판정에 쓰는 ``MemberProfile``(식별자 중심)이다.
/// 한 타입으로 합치지 않는 이유는 `ProfileDTO.toMemberProfile()` 주석에 있다.
/// DTO·엔드포인트는 공유하므로 스키마가 바뀌면 두 경로가 함께 따라간다.
public struct CurrentMemberRepositoryImpl: CurrentMemberRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func currentMember() async throws -> MemberProfile {
        do {
            return try await client.request(UserAPI.me()).toMemberProfile()
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다. `ProfileRepositoryImpl.me()` 와 같은 판단이다.
    ///
    /// 401 은 `unauthorizedReason` 으로 **반드시 나눈다** — 이 엔드포인트의 401 에는
    /// `USER_NOT_REGISTERED`(아직 온보딩 전)가 섞여 있고, 사용자가 할 일이 재로그인과 가입으로
    /// 완전히 다르다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return error.unauthorizedReason
        case 400, 403, 404: return DomainError.profileFetchFailed
        default:
            error.logUntranslated()
            return DomainError.profileFetchFailed
        }
    }
}
