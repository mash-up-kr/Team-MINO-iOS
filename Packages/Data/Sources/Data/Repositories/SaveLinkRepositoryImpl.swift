import Domain
import Foundation
import Logging
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
    /// 화면이 "일부만 성공"을 표현하지 않기로 했으므로 지금은 구분해도 보여줄 자리가 없다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 502: return DomainError.linkSaveFailed
        default:
            // 번역하지 못했다는 사실은 반드시 남긴다. 오류는 `label` 로만 남긴다(서버 원문 유출 방지).
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return DomainError.linkSaveFailed
        }
    }
}
