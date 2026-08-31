import Domain
import Foundation
import Networking

/// 「다른 방에 공유」 저장 (`POST /api/v1/pins/{pinId}/duplicate`).
///
/// 계약: `docs/specs/place-detail/contracts/place-api.md` §4.
/// 짝인 조회는 ``ShareTargetRepositoryImpl`` — 저장은 핀 id, 조회는 장소 id 로 나간다.
public struct SavePinRepositoryImpl: SavePinRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws {
        do {
            _ = try await client.request(PinAPI.duplicate(pinID: pinID.value, roomIDs: roomIDs))
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층. 409(`DUPLICATE_PIN_IN_ROOM`)도 실패로 흡수한다 — 서버가 **전체를 거절**하고,
    /// 화면에 중복을 따로 알리는 자리가 아직 없다(`RoomShareStore` 의 실패 UI TODO). 문구가
    /// 정해지면 그때 전용 `DomainError` 케이스로 가른다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 409, 502: return DomainError.pinShareFailed
        default:
            error.logUntranslated()
            return DomainError.pinShareFailed
        }
    }
}
