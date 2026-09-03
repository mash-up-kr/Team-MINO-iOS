import Foundation
import Testing
@testable import Networking

@Suite("인증 토큰 주입")
struct AuthTokenInjectionTests {
    private static let okBody = Data(#"{"data":{"ok":true}}"#.utf8)

    @Test("인증이 필요한 요청에 Bearer 를 붙인다")
    func attachesBearerWhenRequired() async throws {
        let provider = SpyTokenProvider(initial: "abc")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms"))

        #expect(stub.recorded.first?.authorizationHeader == "Bearer abc")
    }

    // 회원 등록에도 토큰이 필요하다 — 서버가 토큰의 uid 로 누구를 등록할지 정하기 때문이다.
    // 이게 깨지면 최초 진입에서 회원 등록이 통째로 실패한다.
    @Test("unregisteredUser 에도 토큰을 붙인다")
    func attachesBearerEvenWhenNotRequired() async throws {
        let provider = SpyTokenProvider(initial: "abc")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub.body = Self.okBody

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/users", auth: .unregisteredUser))

        #expect(stub.recorded.first?.authorizationHeader == "Bearer abc")
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

    // 재시도 판단은 auth 요구 수준이 아니라 "토큰을 붙였는가" 로 한다.
    @Test("unregisteredUser 요청의 401 도 갱신 후 재시도한다")
    func refreshesEvenForUnauthenticatedEndpoint() async throws {
        let provider = SpyTokenProvider(initial: "old", refreshed: "new")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.enqueue([Self.unauthorized, URLProtocolStub.Stub(body: Self.okBody)])

        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/users", auth: .unregisteredUser))

        #expect(stub.recorded.count == 2)
        #expect(stub.recorded.last?.authorizationHeader == "Bearer new")
    }

    // 온보딩 전 사용자는 앱을 켤 때마다 GET /me 로 이 401 을 받는다. 갱신해도 회원이 생기지
    // 않으므로 재시도는 매 실행마다 낭비되는 왕복 1회일 뿐이다.
    @Test("미등록 401 은 갱신하지 않고 그대로 던진다")
    func doesNotRefreshForUnregisteredUser() async throws {
        let provider = SpyTokenProvider(initial: "old", refreshed: "new")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub = URLProtocolStub.Stub(
            statusCode: 401,
            body: Data(#"{"errorCode":"USER_NOT_REGISTERED","message":"등록되지 않은 사용자입니다."}"#.utf8)
        )

        let error = await capture { try await sut.request(Endpoint<OkResponse>(path: "api/v1/users/me")) }

        #expect(stub.recorded.count == 1)
        #expect(provider.refreshCalls == 0)
        #expect(error == .unauthorized(code: "USER_NOT_REGISTERED", message: "등록되지 않은 사용자입니다."))
    }

    // 토큰 없이 나간 요청을 다시 보내면 바이트까지 같은 요청이 한 번 더 나갈 뿐이다.
    @Test("토큰이 없었으면 401 에도 재시도하지 않는다")
    func doesNotRetryWhenNoTokenWasAttached() async throws {
        let provider = SpyTokenProvider(initial: nil, refreshed: nil)
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub = Self.unauthorized

        _ = await capture { try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms")) }

        #expect(stub.recorded.count == 1)
        #expect(provider.refreshCalls == 0)
    }

    // 갱신했는데 같은 값이면 결과도 같다 — 왕복만 늘어난다.
    @Test("갱신 토큰이 기존과 같으면 재시도하지 않는다")
    func doesNotRetryWhenRefreshedTokenIsUnchanged() async throws {
        let provider = SpyTokenProvider(initial: "same", refreshed: "same")
        let (sut, stub) = makeSUT(tokenProvider: provider)
        stub.stub = Self.unauthorized

        _ = await capture { try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms")) }

        #expect(stub.recorded.count == 1)
        #expect(provider.refreshCalls == 1)   // 갱신은 시도하되 결과가 같아 멈춘다
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
