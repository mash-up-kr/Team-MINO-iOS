import Domain
import Foundation
import Logging
import Networking

/// `SaveLinkRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
///
/// 서버에 "여러 방에 한 번에" 담는 엔드포인트가 없어 **방마다 요청을 따로 보낸다.**
public struct SaveLinkRepositoryImpl: SaveLinkRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func save(url: URL, toRoomIDs roomIDs: Set<String>) async throws {
        let client = self.client
        let failures = await withTaskGroup(of: Error?.self) { group in
            for roomID in roomIDs {
                group.addTask {
                    do {
                        _ = try await client.request(PinAPI.create(roomID: roomID, url: url))
                        return nil
                    } catch let error as NetworkError {
                        return Self.mapToDomain(error)
                    } catch {
                        return error
                    }
                }
            }
            // **실패해도 끝까지 걷는다** — 첫 실패에서 빠져나오면 남은 방은 요청조차 못 나간다.
            // 화면은 "하나라도 실패하면 실패"로 보여주지만, 보낼 수 있는 건 다 보내고 판단한다.
            return await group.reduce(into: [Error]()) { collected, failure in
                if let failure { collected.append(failure) }
            }
        }

        guard !failures.isEmpty else { return }

        // 취소가 섞였으면 취소를 먼저 던진다 — 화면을 떠난 것이지 저장이 실패한 게 아니라,
        // reduce 의 `catch is CancellationError` 가 걸러 오류 UI 를 띄우지 않아야 한다.
        if failures.contains(where: { $0 is CancellationError }) { throw CancellationError() }
        throw failures[0]
    }

    /// 반부패 계층. 400·403 의 `DUPLICATE_PIN_IN_ROOM`(이미 그 방에 있는 링크)도 실패로 흡수한다 —
    /// 화면이 "일부만 성공"을 표현하지 않기로 했으므로 지금은 구분해도 보여줄 자리가 없다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404, 502: return DomainError.linkSaveFailed
        default:
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return DomainError.linkSaveFailed
        }
    }
}
