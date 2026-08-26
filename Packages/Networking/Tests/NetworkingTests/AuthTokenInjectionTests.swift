import Foundation
import Testing
@testable import Networking

@Suite("인증 토큰 주입")
struct AuthTokenInjectionTests {
    private static let okBody = Data(#"{"data":{"ok":true}}"#.utf8)

    @Test("requiresAuth 요청에 Bearer 를 붙인다")
    func attachesBearerWhenRequired() async throws {
        let provider = SpyTokenProvider(initial: "abc")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms"))

        #expect(stub.recorded.first?.authorizationHeader == "Bearer abc")
    }

    // 회원가입·초대조회는 토큰 없이 나가야 한다. 여기가 깨지면 세션 없는 최초 진입이 막힌다.
    @Test("requiresAuth false 면 붙이지 않는다")
    func skipsBearerWhenNotRequired() async throws {
        let provider = SpyTokenProvider()
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/users", requiresAuth: false))

        #expect(stub.recorded.first?.authorizationHeader == nil)
        #expect(provider.tokenCalls == 0)   // 토큰을 물어보지도 않는다
    }

    @Test("공급자가 없으면 인증 없이 나간다")
    func noProviderMeansNoHeader() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms"))

        #expect(stub.recorded.first?.authorizationHeader == nil)
    }

    // 세션이 아직 없는 순간에도 요청은 나가고 서버가 401 로 답한다 —
    // "토큰 없음" 과 "서버 거부" 를 한 갈래로 모으는 설계다.
    @Test("토큰이 nil 이면 헤더 없이 그대로 보낸다")
    func nilTokenSendsWithoutHeader() async throws {
        let provider = SpyTokenProvider(initial: nil, refreshed: nil)
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms"))

        #expect(stub.recorded.first?.authorizationHeader == nil)
    }

    @Test("호출부가 넘긴 Authorization 이 주입값을 이긴다")
    func explicitHeaderWins() async throws {
        let provider = SpyTokenProvider(initial: "injected")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(
            path: "api/v1/rooms",
            headers: ["Authorization": "Bearer explicit"]
        ))

        #expect(stub.recorded.first?.authorizationHeader == "Bearer explicit")
    }
}

@Suite("401 토큰 갱신 재시도")
struct AuthRefreshRetryTests {
    private static let okBody = Data(#"{"data":{"ok":true}}"#.utf8)
    private static var unauthorized: URLProtocolStub.Stub {
        URLProtocolStub.Stub(
            statusCode: 401,
            body: Data(#"{"errorCode":"UNAUTHORIZED","message":"만료"}"#.utf8)
        )
    }

    @Test("401 을 받으면 갱신한 토큰으로 다시 보낸다")
    func retriesWithRefreshedToken() async throws {
        let provider = SpyTokenProvider(initial: "old", refreshed: "new")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.enqueue([Self.unauthorized, URLProtocolStub.Stub(body: Self.okBody)])

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms"))

        #expect(stub.recorded.count == 2)
        #expect(stub.recorded.first?.authorizationHeader == "Bearer old")
        #expect(stub.recorded.last?.authorizationHeader == "Bearer new")
        #expect(provider.refreshCalls == 1)
    }

    // 갱신해도 401 이면 서버가 거부한 것이다. 계속 두드리면 무한 루프가 된다.
    @Test("갱신 후에도 401 이면 더 시도하지 않고 던진다")
    func stopsAfterOneRefresh() async throws {
        let provider = SpyTokenProvider(initial: "old", refreshed: "new")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub = Self.unauthorized

        let error = await capture { try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms")) }

        #expect(stub.recorded.count == 2)
        #expect(provider.refreshCalls == 1)
        #expect(error == .unauthorized(code: "UNAUTHORIZED", message: "만료"))
    }

    @Test("인증이 필요 없는 요청의 401 은 갱신하지 않는다")
    func doesNotRefreshForUnauthenticatedEndpoint() async throws {
        let provider = SpyTokenProvider()
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub = Self.unauthorized

        _ = await capture {
            try await sut.request(Endpoint<OkResponse>(path: "api/v1/users", requiresAuth: false))
        }

        #expect(stub.recorded.count == 1)
        #expect(provider.refreshCalls == 0)
    }

    @Test("공급자가 없으면 401 을 그대로 전파한다")
    func noProviderPropagates401() async throws {
        let (sut, stub) = makeSUT()
        stub.stub = Self.unauthorized

        let error = await capture { try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms")) }

        #expect(stub.recorded.count == 1)
        #expect(error == .unauthorized(code: "UNAUTHORIZED", message: "만료"))
    }
}
