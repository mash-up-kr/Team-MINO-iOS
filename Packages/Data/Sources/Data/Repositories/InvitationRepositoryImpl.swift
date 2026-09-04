import Domain
import Foundation
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

    public func invitationPreview(code: String) async throws -> RoomInvitationPreview {
        do {
            return try await client.request(InvitationAPI.preview(code: code)).toDomain()
        } catch let error as NetworkError {
            throw Self.mapInviteAcceptance(error)
        }
    }

    public func joinRoom(roomId: String, inviteCode: String) async throws {
        do {
            let body = JoinRoomRequestDTO(inviteCode: inviteCode)
            _ = try await client.request(InvitationAPI.join(roomId: roomId, body: body))
        } catch let error as NetworkError {
            throw Self.mapInviteAcceptance(error)
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
            error.logUntranslated()
            return DomainError.inviteCodeFetchFailed
        }
    }

    /// 초대 수락 경로(미리보기·합류)의 번역. **발급(``mapToDomain``)과 나눈다** — 그쪽은 재시도가
    /// 의미 있는 실패 하나로 수렴하지만, 이쪽은 403·404 를 사용자에게 다른 문구로 보여준다.
    ///
    /// 400(`INVALID_INVITE_CODE`)을 나열하지 않는 건 구조적으로 오지 않기 때문이다 — 합류에 쓰는
    /// `roomId` 가 미리보기 응답에서 온 값이라 코드와 방이 어긋날 수 없다. 그래도 오면 로그로 드러난다.
    private static func mapInviteAcceptance(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }

        switch error.statusCode {
        case 401: return error.unauthorizedReason
        case 403: return DomainError.personalRoomNotAllowed
        case 404: return DomainError.invitationNotFound
        default:
            error.logUntranslated()
            // 네트워크에 닿지 못한 것과 서버가 실패한 것을 가른다 — 초대 진입이 이 둘에
            // 다른 문구를 띄운다(연결 안내 vs 만료 안내).
            return error.isNetworkUnavailable ? DomainError.networkUnavailable : DomainError.unknown
        }
    }
}
