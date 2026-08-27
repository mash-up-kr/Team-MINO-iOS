import Domain
import Foundation
import Logging
import Networking

/// `InvitationRepository` 의 네트워크 구현. `AppDependencies` 가 공유 `httpClient` 를 넘긴다.
public struct InvitationRepositoryImpl: InvitationRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func inviteCode(roomId: String) async throws -> String {
        do {
            return try await client.request(InvitationAPI.create(roomId: roomId)).code
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다.** 같은 404 가 본문 모양에 따라
    /// `.notFound` 로도 `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다.
    ///
    /// 403(`NOT_ROOM_MEMBER`·`PERSONAL_ROOM_NOT_ALLOWED`)·404(`ROOM_NOT_FOUND`)를 나누지 않는 건
    /// 셋 다 사용자가 이 화면에서 할 수 있는 일이 같아서다 — 구분해 보여줄 화면이 생기면 그때 쪼갠다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return error.unauthorizedReason
        case 403, 404: return DomainError.inviteCodeFetchFailed
        default:
            // 번역하지 못했다는 사실은 반드시 남긴다 — 어떤 DomainError 를 추가해야 하는지
            // 알 수 있는 유일한 단서다. 오류는 label(케이스 이름)로만 남긴다 —
            // 통째로 찍으면 서버 원문 message 가 릴리즈 기기 로그에 평문으로 남는다(README §금지).
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return DomainError.inviteCodeFetchFailed
        }
    }
}
