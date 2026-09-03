import Domain
import Foundation
import Networking

/// `RoomRepository`·`RoomDetailRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
///
/// 목록과 단건을 **한 타입이 겸한다** — 두 경로가 같은 매핑 규칙(`RoomDTO.toDomain`)을 공유해야
/// 어디로 들어왔든 같은 방이 같게 보인다(`PinRepositoryImpl` 선례).
public struct RoomRepositoryImpl: RoomRepository, RoomDetailRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func rooms() async throws -> [Room] {
        do {
            return try await client.request(RoomAPI.list()).map { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 방 단건. **상세와 멤버를 함께 받는다** — 단건 응답에는 `users` 가 없어서(스펙 확인,
    /// `showUsers` 쿼리도 안 받는다) 상세만 쓰면 방 상세 헤더의 멤버 얼굴이 조용히 빈다.
    /// 두 요청은 서로를 기다릴 이유가 없어 병렬로 낸다.
    public func room(id: String) async throws -> Room {
        do {
            async let detail = client.request(RoomAPI.detail(id))
            async let members = client.request(RoomAPI.members(id))
            return try await detail.toDomain(members: members)
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다** — 같은 404 가 본문 모양에 따라 `.notFound` 로도
    /// `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다.
    ///
    /// 403·404 도 조회 실패로 흡수한다 — 나갔거나 지워진 방을 알림으로 여는 경우가 여기로 온다.
    /// 화면은 "열지 못했다" 만 알리면 되고 사유를 갈라 보여주지 않는다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 403, 404: return DomainError.roomsFetchFailed
        default:
            error.logUntranslated()
            return DomainError.roomsFetchFailed
        }
    }
}
