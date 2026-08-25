import Foundation
import Logging
import Testing
@testable import Networking

private struct DummyDTO: Decodable, Sendable, Equatable {
    let id: String
}

@Suite("Endpoint")
struct EndpointTests {
    @Test("기본값은 GET · 본문 없음 · 인증 필요")
    func defaults() {
        let endpoint = Endpoint<DummyDTO>(path: "api/v1/users/me")
        #expect(endpoint.method == .get)
        #expect(endpoint.queryItems.isEmpty)
        #expect(endpoint.body == nil)
        #expect(endpoint.requiresAuth)
        #expect(endpoint.timeout == nil)
    }

    @Test("paged 는 기존 쿼리를 유지한 채 page·pageSize 를 덧붙인다")
    func paged() {
        let paged: PagedEndpoint<DummyDTO> = Endpoint<[DummyDTO]>(
            path: "api/v1/pins",
            queryItems: [URLQueryItem(name: "roomId", value: "room-1")]
        ).paged(page: 2, pageSize: 20)

        #expect(paged.endpoint.queryItems == [
            URLQueryItem(name: "roomId", value: "room-1"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "pageSize", value: "20"),
        ])
    }

    // 저장해 둔 endpoint 에 paged 를 거듭 적용하는 건 무한스크롤의 흔한 구현이다.
    // 누적되면 `?page=0&page=1` 이 나가고 서버 해석이 갈린다.
    @Test("paged 를 두 번 적용해도 page·pageSize 가 중복되지 않는다")
    func pagedTwice() {
        let base = Endpoint<[DummyDTO]>(path: "api/v1/pins")
        let first: PagedEndpoint<DummyDTO> = base.paged(page: 0, pageSize: 20)
        let second: PagedEndpoint<DummyDTO> = first.endpoint.paged(page: 1, pageSize: 20)

        #expect(second.endpoint.queryItems == [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pageSize", value: "20"),
        ])
    }

    // 서버가 준 pagination.pageSize 를 다음 요청에 그대로 넘기는 게 무한스크롤의 표준
    // 구현이다. 그 값이 스펙을 벗어나도 앱이 죽으면 안 되고, 조용히 눌려서도 안 된다.
    @Test("스펙을 벗어난 값은 크래시 없이 클램프된다", arguments: [
        (-1, 0, "0", "1"),
        (0, 200, "0", "100"),
        (5, 20, "5", "20"),
    ])
    func clampsOutOfSpecValues(_ page: Int, _ pageSize: Int, _ expectedPage: String, _ expectedSize: String) {
        let paged: PagedEndpoint<DummyDTO> = Endpoint<[DummyDTO]>(path: "api/v1/pins")
            .paged(page: page, pageSize: pageSize)

        #expect(paged.endpoint.queryItems == [
            URLQueryItem(name: "page", value: expectedPage),
            URLQueryItem(name: "pageSize", value: expectedSize),
        ])
    }

    // 클램프를 assert 에서 로그로 바꾼 목적이 "릴리즈에서 관측 가능하게" 였다.
    // 값만 검증하면 그 Log.warning 이 지워져도 테스트가 전부 초록이라 목적이 지켜지지 않는다.
    @Test("클램프가 일어나면 요청값·적용값을 로그로 남긴다")
    func clampLogsCorrection() {
        let spy = sharedSpy
        let path = "api/v1/pins/\(uniqueToken())"

        _ = Endpoint<[DummyDTO]>(path: path).paged(page: -1, pageSize: 0) as PagedEndpoint<DummyDTO>

        let entry = try? #require(spy.entry("페이지 파라미터 보정", forPath: path))
        #expect(entry?.metadata["requested"] == "page=-1, pageSize=0")
        #expect(entry?.metadata["applied"] == "page=0, pageSize=1")
    }

    @Test("범위 안 값은 로그를 남기지 않는다 — 정상 호출마다 경고가 쌓이면 안 된다")
    func noLogWhenWithinSpec() {
        let spy = sharedSpy
        let path = "api/v1/pins/\(uniqueToken())"

        _ = Endpoint<[DummyDTO]>(path: path).paged(page: 0, pageSize: 20) as PagedEndpoint<DummyDTO>

        #expect(spy.entry("페이지 파라미터 보정", forPath: path) == nil)
    }
}
