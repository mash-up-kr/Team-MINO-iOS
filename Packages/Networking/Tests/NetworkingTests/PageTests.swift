import Foundation
import Testing
@testable import Networking

private struct DTO: Sendable, Equatable { let id: String }
private struct Entity: Sendable, Equatable { let id: String }   // Decodable 을 붙이지 않는다 — Domain Entity 를 흉내낸다

@Suite("Page")
struct PageTests {
    // 모든 Repository 가 DTO → Entity 로 넘어갈 때 반드시 지나는 이음매다.
    // `Page` 가 Element 에 Decodable 을 요구하지 않는 이유(Entity 에 Codable 금지)가 여기 걸려 있다.
    @Test("map 은 페이지 정보를 유지한 채 알맹이만 바꾼다")
    func mapKeepsPagination() {
        let page = Page(
            items: [DTO(id: "1"), DTO(id: "2")],
            pagination: Pagination(pageSize: 20, page: 3, hasNext: true)
        )

        let mapped: Page<Entity> = page.map { Entity(id: $0.id) }

        #expect(mapped.items == [Entity(id: "1"), Entity(id: "2")])
        #expect(mapped.pagination == page.pagination)
    }

    @Test("map 안에서 던진 오류는 그대로 전파된다")
    func mapRethrows() {
        struct Boom: Error {}
        let page = Page(items: [DTO(id: "1")], pagination: Pagination(pageSize: 20, page: 0, hasNext: false))

        #expect(throws: Boom.self) {
            _ = try page.map { _ -> Entity in throw Boom() }
        }
    }
}
