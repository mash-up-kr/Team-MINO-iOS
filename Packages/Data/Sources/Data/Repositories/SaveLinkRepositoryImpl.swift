import Domain
import Foundation
import Networking

/// `SaveLinkRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct SaveLinkRepositoryImpl: SaveLinkRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func save(url: URL, toRoomIDs roomIDs: Set<String>) async throws {
        do {
            _ = try await client.request(PinAPI.create(url: url, roomIDs: roomIDs))
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층. 400·403 의 `DUPLICATE_PIN_IN_ROOM`(이미 그 방에 있는 링크)도 실패로 흡수한다 —
    /// 시안에 중복 저장을 따로 알리는 자리가 없어 구분해도 보여줄 곳이 없다. 문구가 생기면 그때
    /// `DomainError` 케이스를 추가한다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 502: return DomainError.linkSaveFailed
        default:
            error.logUntranslated()
            return DomainError.linkSaveFailed
        }
    }
}
