import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 푸시 토큰 등록의 계약을 고정한다 — 어떤 경로·메서드로 나가고, 바디에 토큰만 실리며,
/// 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("PushTokenRepositoryImpl")
struct PushTokenRepositoryImplTests {
    @Test("PUT api/v1/users/me/push-token 으로 토큰만 싣는다")
    func register_sendsTokenOnly() async throws {
        let client = StubHTTPClient()
        let sut = PushTokenRepositoryImpl(client: client)

        try await sut.register(token: "fcm-token-1")

        #expect(await client.callCount == 1)
        #expect(await client.lastPath == "api/v1/users/me/push-token")
        #expect(await client.lastMethod == .put)
        #expect(await client.lastToken == "fcm-token-1")
        #expect(await client.lastBodyKeys == ["token"])
    }

    // 미등록은 재로그인이 아니라 온보딩이 답이라 401 안에서 갈라야 한다.
    @Test("미등록(USER_NOT_REGISTERED)은 notRegistered 로 갈린다")
    func userNotRegisteredIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "USER_NOT_REGISTERED", message: "미등록"))
        let sut = PushTokenRepositoryImpl(client: client)

        await #expect(throws: DomainError.notRegistered) {
            try await sut.register(token: "fcm-token-1")
        }
    }

    @Test("그 밖의 401 은 재인증이 필요한 unauthorized 다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = PushTokenRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.register(token: "fcm-token-1")
        }
    }

    @Test("번역되지 않은 상태코드는 unknown 으로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = PushTokenRepositoryImpl(client: client)

        await #expect(throws: DomainError.unknown) {
            try await sut.register(token: "fcm-token-1")
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = PushTokenRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.register(token: "fcm-token-1")
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
private actor StubHTTPClient: HTTPClient {
    private let error: Error?
    private(set) var callCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private var lastBody: [String: Any]?

    init(error: Error? = nil) { self.error = error }

    var lastToken: String? { lastBody?["token"] as? String }
    /// 토큰 말고 다른 게 딸려 나가지 않는지 본다 — 서버는 `token` 하나만 받는다.
    var lastBodyKeys: [String]? { lastBody?.keys.sorted() }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        callCount += 1
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        return try APIDecoder.make().decode(T.self, from: Data(#"{"ok":true}"#.utf8))
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 토큰 등록은 페이지네이션을 쓰지 않는다
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
