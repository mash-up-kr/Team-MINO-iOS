import Domain
import Foundation
import Logging
import Networking

/// `RoomMembershipRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
public struct RoomMembershipRepositoryImpl: RoomMembershipRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func leave(roomId: String) async throws {
        do {
            _ = try await client.request(RoomAPI.leave(roomId))
        } catch let error as NetworkError {
            throw Self.mapLeave(error)
        }
    }

    public func transferOwner(roomId: String, nextOwnerId: String) async throws {
        do {
            _ = try await client.request(
                RoomAPI.transferOwner(roomId, TransferOwnerRequestDTO(nextOwnerId: nextOwnerId))
            )
        } catch let error as NetworkError {
            throw Self.mapTransfer(error)
        }
    }

    /// 반부패 계층 — 나가기.
    ///
    /// **409 만 따로 집는다.** 그건 실패가 아니라 "위임을 먼저 하라" 는 다음 절차의 요구이고,
    /// 화면이 이 값 하나로 안내 대신 새 방장 고르기를 띄운다. 코드까지 대조하는 이유는 같은 409 를
    /// 다른 사유로 쓰게 되면 엉뚱한 화면이 뜨기 때문이다.
    private static func mapLeave(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다
        if case .conflict(let code, _) = error, code == "OWNER_TRANSFER_REQUIRED" {
            return DomainError.ownerTransferRequired
        }

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        // 403(멤버 아님)·404(없는 방)는 결과가 같다 — 이미 그 방에 없다. 안내 문구를 가를
        // 화면이 없어 나가기 실패로 흡수한다.
        case 400, 403, 404, 409: return DomainError.roomLeaveFailed
        default:
            error.logUntranslated()
            return DomainError.roomLeaveFailed
        }
    }

    /// 반부패 계층 — 방장 위임. 400(대상이 멤버가 아님)·403(방장 아님) 모두 위임 실패로 모은다.
    private static func mapTransfer(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404: return DomainError.ownerTransferFailed
        default:
            error.logUntranslated()
            return DomainError.ownerTransferFailed
        }
    }
}
