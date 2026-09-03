import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 코멘트 조회·등록·삭제의 계약을 고정한다 — 어떤 경로로 나가고, 여러 장이 어떤 순서로
/// 이어지며, 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("PinCommentRepositoryImpl")
struct PinCommentRepositoryImplTests {
    private static let pinID = PinID("pin-1")

    /// 항목 하나. 검증 대상이 아닌 필드를 케이스마다 손으로 짓지 않도록 모은다.
    private static func itemJSON(
        id: String,
        content: String,
        createdAt: String,
        authorID: String = "user-2",
        nickname: String = "서연",
        avatar: String = #"{"color":"orange"}"#,
        canDelete: Bool = false
    ) -> String {
        """
        {
          "id": "\(id)", "content": "\(content)", "createdAt": "\(createdAt)",
          "author": { "id": "\(authorID)", "nickname": "\(nickname)", "avatar": \(avatar) },
          "canDelete": \(canDelete)
        }
        """
    }

    // MARK: - 조회: 장 잇기

    // 서버 정렬은 대화창 순서다 — page=0 이 최신 묶음, 장 안에서는 오래된 것이 앞.
    // 화면은 전체를 오래된 → 최신 한 줄로 그리므로 장 사이만 뒤집혀야 한다.
    @Test("여러 장을 오래된 → 최신 한 줄로 잇는다 — 장 안의 순서는 그대로 둔다")
    func comments_joinsPagesOldestFirst() async throws {
        let client = StubHTTPClient(pages: [
            // page=0 — 가장 최신 묶음
            .init(json: "[\(Self.itemJSON(id: "c3", content: "셋", createdAt: "2026-08-03T09:00:00Z")),"
                      + "\(Self.itemJSON(id: "c4", content: "넷", createdAt: "2026-08-04T09:00:00Z"))]",
                  hasNext: true),
            // page=1 — 더 예전 묶음
            .init(json: "[\(Self.itemJSON(id: "c1", content: "하나", createdAt: "2026-08-01T09:00:00Z")),"
                      + "\(Self.itemJSON(id: "c2", content: "둘", createdAt: "2026-08-02T09:00:00Z"))]",
                  hasNext: false),
        ])
        let sut = PinCommentRepositoryImpl(client: client)

        let comments = try await sut.comments(pinID: Self.pinID)

        #expect(comments.map(\.id.value) == ["c1", "c2", "c3", "c4"])
        #expect(comments.map(\.body) == ["하나", "둘", "셋", "넷"])
        #expect(comments.allSatisfy { $0.pinID == Self.pinID })   // 응답에 없는 핀은 요청이 돌려준다
    }

    @Test("GET api/v1/pins/{pinId}/comments 로 나가고 장마다 page 가 하나씩 오른다")
    func comments_targetsPathAndAdvancesPage() async throws {
        let client = StubHTTPClient(pages: [
            .init(json: "[\(Self.itemJSON(id: "c2", content: "둘", createdAt: "2026-08-02T09:00:00Z"))]", hasNext: true),
            .init(json: "[\(Self.itemJSON(id: "c1", content: "하나", createdAt: "2026-08-01T09:00:00Z"))]", hasNext: false),
        ])
        let sut = PinCommentRepositoryImpl(client: client)

        _ = try await sut.comments(pinID: Self.pinID)

        #expect(await client.pagedPaths == ["api/v1/pins/pin-1/comments", "api/v1/pins/pin-1/comments"])
        #expect(await client.pagedQueryValues("page") == ["0", "1"])
        // 전부 받는 것이 목적이라 스펙 최대치를 쓴다 — 서버 기본값(20)이면 왕복이 5배가 된다.
        #expect(await client.pagedQueryValues("pageSize") == ["100", "100"])
    }

    @Test("hasNext 가 false 면 거기서 멈춘다 — 다음 장을 더 부르지 않는다")
    func comments_stopsWhenNoNextPage() async throws {
        let client = StubHTTPClient(pages: [
            .init(json: "[\(Self.itemJSON(id: "c1", content: "하나", createdAt: "2026-08-01T09:00:00Z"))]", hasNext: false),
            // 부르면 안 되는 장. 불렸다면 아래 개수 단언이 깨진다.
            .init(json: "[\(Self.itemJSON(id: "c0", content: "영", createdAt: "2026-07-01T09:00:00Z"))]", hasNext: false),
        ])
        let sut = PinCommentRepositoryImpl(client: client)

        let comments = try await sut.comments(pinID: Self.pinID)

        #expect(await client.pagedQueryValues("page") == ["0"])
        #expect(comments.map(\.id.value) == ["c1"])
    }

    @Test("항목이 없으면 빈 목록 — 한 번만 묻는다")
    func comments_emptyPage() async throws {
        let client = StubHTTPClient(pages: [.init(json: "[]", hasNext: false)])
        let sut = PinCommentRepositoryImpl(client: client)

        #expect(try await sut.comments(pinID: Self.pinID).isEmpty)
        #expect(await client.pagedQueryValues("page") == ["0"])
    }

    // MARK: - 조회: 매핑

    @Test("아바타가 null 이면 색이 없고, 팔레트에 없는 색도 nil 로 떨어진다")
    func comments_avatarFallsBackToNil() async throws {
        let client = StubHTTPClient(pages: [
            .init(json: """
            [\(Self.itemJSON(id: "c1", content: "없음", createdAt: "2026-08-01T09:00:00Z", avatar: "null")),
             \(Self.itemJSON(id: "c2", content: "모름", createdAt: "2026-08-02T09:00:00Z",
                             avatar: #"{"color":"chartreuse"}"#))]
            """, hasNext: false),
        ])
        let sut = PinCommentRepositoryImpl(client: client)

        let comments = try await sut.comments(pinID: Self.pinID)

        #expect(comments[0].author.avatarColor == nil)
        #expect(comments[1].author.avatarColor == nil)
        #expect(comments[1].author.nickname == "서연")   // 나머지 필드는 살아남는다
    }

    // 서버는 `canDelete` 를 주지만 화면은 CurrentMember 로 소유를 판정한다 — 두 답이 생기지
    // 않도록 Domain 으로 옮기지 않는다. 필수 필드라 디코딩은 한다.
    @Test("canDelete 는 디코딩되지만 Domain 값에는 실리지 않는다")
    func canDelete_decodedButNotCarriedToDomain() throws {
        let json = Self.itemJSON(
            id: "c1", content: "내 코멘트", createdAt: "2026-08-01T09:00:00Z",
            authorID: "user-1", nickname: "나", canDelete: true
        )
        let dto = try APIDecoder.make().decode(PinCommentDTO.self, from: Data(json.utf8))
        let createdAt = try Date("2026-08-01T09:00:00Z", strategy: .iso8601)

        #expect(dto.canDelete)   // 계약대로 읽힌다

        // 같은 응답의 Domain 값은 canDelete 없이 전부 결정된다 — 값이 하나라도 그 필드에서
        // 왔다면 아래 직접 지은 코멘트와 달라진다.
        #expect(dto.toDomain(pinID: Self.pinID) == PinComment(
            id: PinCommentID("c1"),
            pinID: Self.pinID,
            author: MemberProfile(id: MemberID("user-1"), nickname: "나", avatarColor: .orange),
            body: "내 코멘트",
            createdAt: createdAt
        ))
    }

    // MARK: - 등록

    @Test("등록은 POST 로 나가고 본문 키는 content 이며 서버가 채운 코멘트를 돌려준다")
    func post_sendsContentAndReturnsServerComment() async throws {
        let client = StubHTTPClient(json: Self.itemJSON(
            id: "c-new", content: "좋았어요", createdAt: "2026-08-05T09:00:00Z",
            authorID: "user-1", nickname: "나", canDelete: true
        ))
        let sut = PinCommentRepositoryImpl(client: client)

        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")

        #expect(await client.lastPath == "api/v1/pins/pin-1/comments")
        #expect(await client.lastMethod == .post)
        // Domain 은 `body`, 서버는 `content` — 어휘가 어긋나면 400 이다.
        #expect(await client.lastBodyValue("content") == "좋았어요")
        #expect(await client.lastBodyValue("body") == nil)
        #expect(posted.id == PinCommentID("c-new"))
        #expect(posted.pinID == Self.pinID)
        #expect(posted.author == MemberProfile(id: MemberID("user-1"), nickname: "나", avatarColor: .orange))
        #expect(posted.createdAt == (try Date("2026-08-05T09:00:00Z", strategy: .iso8601)))
    }

    // MARK: - 삭제

    @Test("삭제는 DELETE 로 나가고 경로에 핀과 코멘트가 함께 들어간다")
    func delete_targetsPinScopedPath() async throws {
        let client = StubHTTPClient(json: #"{"ok":true}"#)
        let sut = PinCommentRepositoryImpl(client: client)

        try await sut.delete(pinID: Self.pinID, commentID: PinCommentID("c-9"))

        #expect(await client.lastPath == "api/v1/pins/pin-1/comments/c-9")
        #expect(await client.lastMethod == .delete)
    }

    // MARK: - 오류 번역

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let error = NetworkError.unauthorized(code: "UNIDENTIFIED_USER", message: "인증 정보가 없습니다.")

        await #expect(throws: DomainError.unauthorized) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error)).comments(pinID: Self.pinID)
        }
        await #expect(throws: DomainError.unauthorized) {
            _ = try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .post(pinID: Self.pinID, body: "좋았어요")
        }
        await #expect(throws: DomainError.unauthorized) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .delete(pinID: Self.pinID, commentID: PinCommentID("c-9"))
        }
    }

    @Test("작성자가 아니라는 403 은 삭제 실패로 흡수된다 — 구분해 보여줄 화면이 아직 없다")
    func deleteForbiddenBecomesDeleteFailure() async {
        let client = StubHTTPClient(
            error: NetworkError.forbidden(code: "COMMENT_DELETE_FORBIDDEN", message: "권한 없음")
        )
        let sut = PinCommentRepositoryImpl(client: client)

        await #expect(throws: DomainError.commentDeleteFailed) {
            try await sut.delete(pinID: Self.pinID, commentID: PinCommentID("c-9"))
        }
    }

    @Test("번역되지 않은 상태코드는 각 동작의 실패 어휘로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let error = NetworkError.server(statusCode: 500)

        await #expect(throws: DomainError.commentsFetchFailed) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error)).comments(pinID: Self.pinID)
        }
        await #expect(throws: DomainError.commentPostFailed) {
            _ = try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .post(pinID: Self.pinID, body: "좋았어요")
        }
        await #expect(throws: DomainError.commentDeleteFailed) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .delete(pinID: Self.pinID, commentID: PinCommentID("c-9"))
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let error = NetworkError.cancelled

        await #expect(throws: CancellationError.self) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error)).comments(pinID: Self.pinID)
        }
        await #expect(throws: CancellationError.self) {
            _ = try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .post(pinID: Self.pinID, body: "좋았어요")
        }
        await #expect(throws: CancellationError.self) {
            try await PinCommentRepositoryImpl(client: StubHTTPClient(error: error))
                .delete(pinID: Self.pinID, commentID: PinCommentID("c-9"))
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubHTTPClient: HTTPClient {
    /// 페이지네이션 응답 한 장. `requestPage` 가 부른 순서대로 소비한다.
    struct PageStub {
        let json: String
        let hasNext: Bool
    }

    private let pages: [PageStub]
    private let json: String?
    private let error: Error?
    private var nextPageIndex = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private(set) var lastBody: [String: Any]?
    private(set) var pagedPaths: [String] = []
    private(set) var pagedQueries: [[URLQueryItem]] = []

    init(pages: [PageStub] = [], json: String? = nil, error: Error? = nil) {
        self.pages = pages
        self.json = json
        self.error = error
    }

    /// 장마다 실려 나간 쿼리 값. 순서까지 본다 — page 가 오르지 않으면 첫 장만 반복해 받는다.
    func pagedQueryValues(_ name: String) -> [String] {
        pagedQueries.compactMap { $0.first { $0.name == name }?.value }
    }

    /// 요청 본문의 문자열 값. 키 자체가 없으면 nil.
    func lastBodyValue(_ key: String) -> String? {
        lastBody?[key] as? String
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    // Domain 에도 같은 이름의 `Page` 가 있어 모듈로 한정한다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        pagedPaths.append(endpoint.endpoint.path)
        pagedQueries.append(endpoint.endpoint.queryItems)

        if let error { throw error }
        // 준비한 장보다 더 부르면 계약 위반이다 — 조용한 빈 장으로 덮으면 "안 멈춘다" 를 놓친다.
        guard nextPageIndex < pages.count else {
            throw NetworkError.server(statusCode: 599)
        }
        let stub = pages[nextPageIndex]
        nextPageIndex += 1
        return Networking.Page(
            items: try APIDecoder.make().decode([Element].self, from: Data(stub.json.utf8)),
            pagination: Pagination(pageSize: 100, page: nextPageIndex - 1, hasNext: stub.hasNext)
        )
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
