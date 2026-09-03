import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 내 신원 조회의 계약을 고정한다 — 프로필 응답이 어떤 ``MemberProfile`` 이 되고,
/// 401 의 두 갈래(재인증 vs 미등록)가 어떻게 갈리는지.
@Suite("CurrentMemberRepositoryImpl")
struct CurrentMemberRepositoryImplTests {
    @Test("GET api/v1/users/me 로 나가고 응답이 신원으로 매핑된다")
    func currentMember_mapsResponse() async throws {
        let client = StubHTTPClient(json: """
        { "id": "user-1", "nickname": "꾹이", "avatar": { "color": "light_blue" },
          "createdAt": "2026-08-01T09:00:00Z" }
        """)
        let sut = CurrentMemberRepositoryImpl(client: client)

        let me = try await sut.currentMember()

        #expect(await client.lastPath == "api/v1/users/me")
        #expect(await client.lastMethod == .get)
        #expect(me == MemberProfile(id: MemberID("user-1"), nickname: "꾹이", avatarColor: .lightBlue))
    }

    @Test("아바타가 null 이면 색이 없고, 팔레트에 없는 색도 nil 로 떨어진다")
    func currentMember_avatarFallsBackToNil() async throws {
        let missing = StubHTTPClient(json: """
        { "id": "user-1", "nickname": "꾹이", "avatar": null, "createdAt": "2026-08-01T09:00:00Z" }
        """)
        let unknown = StubHTTPClient(json: """
        { "id": "user-1", "nickname": "꾹이", "avatar": { "color": "chartreuse" },
          "createdAt": "2026-08-01T09:00:00Z" }
        """)

        #expect(try await CurrentMemberRepositoryImpl(client: missing).currentMember().avatarColor == nil)

        let fallback = try await CurrentMemberRepositoryImpl(client: unknown).currentMember()
        #expect(fallback.avatarColor == nil)
        #expect(fallback.nickname == "꾹이")   // 나머지 필드는 살아남는다
    }

    // 세션은 유효한데 아직 가입 전인 401 이 섞여 온다 — 재로그인과 온보딩은 사용자가 할 일이
    // 완전히 다르므로 반드시 갈린다(`ProfileRepositoryImpl.me()` 와 같은 판단).
    @Test("401 은 errorCode 로 재인증과 미등록을 가른다")
    func unauthorizedSplitsByErrorCode() async {
        let expired = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let unregistered = StubHTTPClient(
            error: NetworkError.unauthorized(code: "USER_NOT_REGISTERED", message: "미등록")
        )

        await #expect(throws: DomainError.unauthorized) {
            try await CurrentMemberRepositoryImpl(client: expired).currentMember()
        }
        await #expect(throws: DomainError.notRegistered) {
            try await CurrentMemberRepositoryImpl(client: unregistered).currentMember()
        }
    }

    @Test("번역되지 않은 상태코드는 프로필 조회 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))

        await #expect(throws: DomainError.profileFetchFailed) {
            try await CurrentMemberRepositoryImpl(client: client).currentMember()
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)

        await #expect(throws: CancellationError.self) {
            try await CurrentMemberRepositoryImpl(client: client).currentMember()
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    // Domain 에도 같은 이름의 `Page` 가 있어 모듈로 한정한다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 내 신원 조회는 페이지네이션을 쓰지 않는다
    }
}
