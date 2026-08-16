import Foundation
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
}
