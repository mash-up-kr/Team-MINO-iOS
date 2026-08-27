import Domain
import Foundation
import Logging
import Networking

/// `RoomEditingRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct RoomEditingRepositoryImpl: RoomEditingRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func create(name: String, description: String?, color: RoomColor) async throws -> Room {
        try await send(RoomAPI.create(SaveRoomRequestDTO(name: name, description: description, color: color)))
    }

    public func update(
        roomId: String,
        name: String,
        description: String?,
        color: RoomColor
    ) async throws -> Room {
        try await send(RoomAPI.update(roomId, SaveRoomRequestDTO(name: name, description: description, color: color)))
    }

    private func send(_ endpoint: Endpoint<RoomDTO>) async throws -> Room {
        do {
            return try await client.request(endpoint).toDomain()
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다** — 같은 404 가 본문 모양에 따라 `.notFound` 로도
    /// `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다.
    ///
    /// 403(방장 아님)은 아직 구분해 보여줄 화면이 없어 저장 실패로 흡수한다. 편집 진입점이
    /// 붙을 때 화면이 문구를 갈라야 하면 그때 `DomainError` 케이스를 추가한다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 422: return DomainError.roomSaveFailed
        default:
            // 번역하지 못했다는 사실은 반드시 남긴다 — 어떤 DomainError 를 추가해야 하는지
            // 알 수 있는 유일한 단서다. 오류는 `label` 로만 남긴다(서버 원문 message 유출 방지).
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return DomainError.roomSaveFailed
        }
    }
}
