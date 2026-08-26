import Testing
import Domain
import Networking
@testable import Data

/// `Networking.Page` → `Domain.Page` 경계 매핑 테스트.
///
/// envelope(`{data, pagination}`) 디코딩 자체는 여기서 보지 않는다 — Networking 이 소유하고
/// `URLSessionHTTPClientTests`(`pagination` 누락·필드 결손을 계약 위반으로 드러내는지)와
/// `PageTests` 가 이미 검증한다. 이 스위트는 그 뒤, **Data 가 더하는 판단**만 본다:
/// 다음 장 크기를 응답이 아니라 요청에서 가져온다는 정책.
@Suite("페이지 경계 매핑")
struct PageMappingTests {
    /// 매핑 실패를 유발하기 위한 더미 에러.
    private struct StubTransformError: Error, Equatable {}

    private func page(
        _ items: [String],
        pageSize: Int,
        page: Int,
        hasNext: Bool
    ) -> Networking.Page<String> {
        Networking.Page(items: items, pagination: Pagination(pageSize: pageSize, page: page, hasNext: hasNext))
    }

    @Test("한 장을 Domain 값 타입으로 옮긴다")
    func mapsToDomainPage() {
        let source = page(["a", "b"], pageSize: 50, page: 2, hasNext: true)

        let mapped = source.toDomain(request: PageRequest(page: 2, pageSize: 50)) { $0.uppercased() }

        #expect(mapped.items == ["A", "B"])
        #expect(mapped.page == 2)
        #expect(mapped.pageSize == 50)
        #expect(mapped.hasNext == true)
    }

    @Test("항목이 비어도 페이지 정보는 유지된다")
    func emptyItemsKeepPagination() {
        let source = page([], pageSize: 20, page: 3, hasNext: false)

        let mapped = source.toDomain(request: PageRequest(page: 3, pageSize: 20)) { $0 }

        #expect(mapped.items.isEmpty)
        #expect(mapped.page == 3)
        #expect(mapped.pageSize == 20)
        #expect(mapped.hasNext == false)
    }

    @Test("항목 매핑이 던지면 그대로 전파된다")
    func transformErrorPropagates() {
        let source = page(["a", "b"], pageSize: 20, page: 0, hasNext: false)

        #expect(throws: StubTransformError.self) {
            try source.toDomain(request: PageRequest(page: 0, pageSize: 20)) { _ in throw StubTransformError() }
        }
    }

    @Test("서버가 실제 담긴 개수를 pageSize 로 돌려줘도 다음 장 크기는 요청값을 유지한다")
    func responsePageSizeDoesNotShrinkNextRequest() {
        // 20개를 요청했는데 서버가 필터링 후 pageSize 17 을 돌려준 상황. 응답값을 되먹이면
        // 다음 요청이 page=1&pageSize=17 이 되어 오프셋이 어긋나고 이미 본 항목이 다시 온다.
        // Networking 은 서버 값을 그대로 전달할 뿐이라, 이 선택은 이 매핑이 쥐고 있다.
        let source = page(["a"], pageSize: 17, page: 0, hasNext: true)

        let mapped = source.toDomain(request: PageRequest(page: 0, pageSize: 20)) { $0 }

        #expect(mapped.pageSize == 20)
        #expect(mapped.next == PageRequest(page: 1, pageSize: 20))
    }

    @Test("현재 위치는 요청값이 아니라 응답이 알려준 page 를 따른다")
    func pageComesFromResponseNotRequest() {
        // 서버가 요청 page 를 clamp 하거나 무시하면 그 사실이 Page.page 에 드러나야 한다.
        let source = page(["a"], pageSize: 20, page: 2, hasNext: true)

        let mapped = source.toDomain(request: PageRequest(page: 5, pageSize: 20)) { $0 }

        #expect(mapped.page == 2)
    }

    @Test("기본 페이지 크기는 서버 기본값과 같다")
    func defaultPageSizeMatchesServerDefault() {
        // Swagger pageSize 파라미터의 Default value.
        #expect(PageRequest.defaultPageSize == 20)
    }
}
