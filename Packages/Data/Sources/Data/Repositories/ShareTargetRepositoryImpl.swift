import Domain
import Foundation
import Networking

/// 「다른 방에 공유」 후보 조회 (`GET /api/v1/rooms?showHasPlaceId={placeId}`).
///
/// 계약: `docs/specs/place-detail/contracts/place-api.md` §3.
/// 방 목록과 "그 방에 이 장소가 있는지"(`hasPlace`)가 **한 응답으로** 온다 — 나눠 받으면 화면이
/// 두 소스를 대조해야 하고 그 사이에 다른 기기가 저장하면 체크 상태가 어긋난다.
///
/// `showUsers` 는 붙이지 않는다 — 공유 시트 카드에 멤버 아바타를 넣지 않는다(계약 §3).
public struct ShareTargetRepositoryImpl: ShareTargetRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func shareTargets(placeID: PlaceID) async throws -> [ShareTarget] {
        do {
            let rooms = try await client.request(
                RoomAPI.list(showUsers: false, hasPlaceID: placeID.value)
            )
            // `hasPlace` 는 `?showHasPlaceId=` 를 붙였을 때만 온다. 그래도 nil 이면 "모른다" 가
            // 아니라 **안 담겼다**로 본다 — 담긴 방을 안 담겼다고 보이면 사용자가 한 번 더 고르고
            // 서버가 409 로 거절할 뿐이지만, 반대로 보이면 담을 수 있는 방을 막아 버린다.
            return rooms.map { ShareTarget(room: $0.toDomain(), alreadySaved: $0.hasPlace ?? false) }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층. 목록을 못 읽으면 시트가 그릴 것이 없으므로 방 조회 실패로 수렴한다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 502: return DomainError.roomsFetchFailed
        default:
            error.logUntranslated()
            return DomainError.roomsFetchFailed
        }
    }
}
