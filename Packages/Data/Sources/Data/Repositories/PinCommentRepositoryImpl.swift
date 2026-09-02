import Domain
import Foundation
import Logging
import Networking

/// `PinCommentRepository` 의 실 API 구현. 절차: `Packages/Networking/Docs/AddingAPI.md`.
///
/// 조회만 페이지네이션이다. 화면(기획 005-1)은 코멘트를 **한 줄로 다 펼쳐** 보여주고 더보기가
/// 없으므로, Domain 인터페이스(``PinCommentRepository/comments(pinID:)``)도 페이지를 노출하지
/// 않는다 — 여기서 끝까지 받아 하나로 잇는다.
public struct PinCommentRepositoryImpl: PinCommentRepository {
    private let client: HTTPClient

    /// 한 번에 받아 올 코멘트 수. **스펙 최대치(1~100)를 그대로 쓴다** — 전부 받는 것이 목적이라
    /// 장이 적을수록 왕복이 줄고, 서버 기본값(20)을 쓰면 100개짜리 장소에서 5번을 오간다.
    private static let pageSize = 100

    /// 이어 받을 장의 상한. `hasNext` 만 믿고 도는 루프라 서버가 그 값을 늘 true 로 주면
    /// **영원히 멈추지 않는다**(화면은 로딩에 갇히고 요청만 계속 나간다). 상한에 닿으면 지금까지
    /// 받은 것으로 답하고 사실을 로그에 남긴다 — 조용히 끊으면 "코멘트가 여기까지뿐" 으로 보인다.
    private static let pageLimit = 50

    public init(client: HTTPClient) {
        self.client = client
    }

    /// 오래된 것부터 하나로 이어 돌려준다.
    ///
    /// 서버 정렬은 **대화창 순서**다(2026-08-31 확정) — page=0 이 가장 최신 묶음이고 page 가
    /// 커질수록 예전 묶음이며, 한 장 안에서는 오래된 것이 앞이다. 그래서 장 **안**의 순서는 그대로
    /// 두고 장 **사이**만 뒤집으면 전체가 오래된 → 최신 한 줄이 된다.
    public func comments(pinID: PinID) async throws -> [PinComment] {
        do {
            var pages: [[PinComment]] = []
            var page = 0
            while true {
                // 화면 이탈로 취소됐으면 다음 장을 부르지 않는다 — 요청 사이에도 취소가 걸리게 한다.
                try Task.checkCancellation()
                let received = try await client.requestPage(
                    PinAPI.comments(pinID: pinID.value, page: page, pageSize: Self.pageSize)
                )
                pages.append(received.items.map { $0.toDomain(pinID: pinID) })
                guard received.pagination.hasNext else { break }

                page += 1
                guard page < Self.pageLimit else {
                    Log.warning("코멘트 페이지 상한에 걸려 중단", metadata: [
                        "pages": String(Self.pageLimit),
                        "pageSize": String(Self.pageSize),
                    ])
                    break
                }
            }
            return pages.reversed().flatMap { $0 }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error, fallback: .commentsFetchFailed)
        }
    }

    public func post(pinID: PinID, body: String) async throws -> PinComment {
        do {
            // 서버가 식별자·작성자·작성 시각을 채워 준 그 줄을 그대로 돌려준다 — 클라이언트가
            // 지어낸 값을 섞으면 그 id 로 삭제가 안 된다(프로토콜 주석 참고).
            return try await client.request(PinAPI.postComment(pinID: pinID.value, content: body))
                .toDomain(pinID: pinID)
        } catch let error as NetworkError {
            throw Self.mapToDomain(error, fallback: .commentPostFailed)
        }
    }

    public func delete(pinID: PinID, commentID: PinCommentID) async throws {
        do {
            _ = try await client.request(
                PinAPI.deleteComment(pinID: pinID.value, commentID: commentID.value)
            )
        } catch let error as NetworkError {
            throw Self.mapToDomain(error, fallback: .commentDeleteFailed)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다** — 같은 404 가 본문 모양에 따라 `.notFound` 로도
    /// `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다(`RoomRepositoryImpl` 과 같은 이유).
    ///
    /// 403 은 두 갈래(`NOT_ROOM_MEMBER`·`COMMENT_DELETE_FORBIDDEN`)지만 둘 다 폴백으로 흡수한다 —
    /// 화면에 "방을 나갔다"·"남의 코멘트다"를 따로 알릴 자리가 아직 없다. 문구가 생기면 그때
    /// `DomainError` 케이스로 가른다.
    ///
    /// 401 은 `unauthorizedReason` 으로 나누지 않는다 — 코멘트 API 의 401 은 `UNIDENTIFIED_USER`
    /// 하나뿐이라(스펙) 미등록을 가릴 대상이 없다. 미등록 분기는 진입 경로
    /// (`ProfileRepositoryImpl`·``CurrentMemberRepositoryImpl``)가 이미 맡는다.
    private static func mapToDomain(_ error: NetworkError, fallback: DomainError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 400, 403, 404: return fallback
        default:
            error.logUntranslated()
            return fallback
        }
    }
}
