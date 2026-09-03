import Domain
import Foundation
import Networking

/// `PinRepository`·`PinDetailRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
///
/// 목록과 상세를 **한 타입이 겸한다** — 상세가 목록에 없는 값을 지어내지 않게 같은 매핑 규칙을
/// 공유하려는 것이다(목 시절 `MockPinRepository` 가 한 판단을 그대로 잇는다).
public struct PinRepositoryImpl: PinRepository, PinDetailRepository, PinAccessRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func cards(roomID: String, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] {
        do {
            return try await client.request(PinAPI.cards(roomID: roomID, filter: filter, origin: origin))
                .cards.map { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    public func pins(roomID: String) async throws -> [Pin] {
        do {
            return try await client.request(PinAPI.list(roomID: roomID)).map { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    public func pinDetail(id: PinID) async throws -> PinDetail {
        do {
            return try await client.request(PinAPI.detail(pinID: id.value)).toDomain()
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    public func recordAccess(pinID: PinID) async throws {
        do {
            _ = try await client.request(PinAPI.recordAccess(pinID: pinID.value))
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다** — 같은 404 가 본문 모양에 따라 `.notFound` 로도
    /// `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다(`RoomRepositoryImpl` 과 같은 이유).
    ///
    /// 403(`NOT_ROOM_MEMBER`)도 조회 실패로 흡수한다 — 이미 나간 방의 덱을 마저 부르는 정도라
    /// 화면에 따로 보여 줄 자리가 없다. 문구가 생기면 그때 `DomainError` 케이스를 추가한다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404: return DomainError.pinsFetchFailed
        default:
            error.logUntranslated()
            return DomainError.pinsFetchFailed
        }
    }
}
