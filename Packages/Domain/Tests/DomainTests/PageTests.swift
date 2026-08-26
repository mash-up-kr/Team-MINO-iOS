import Testing
@testable import Domain

/// 값 자체에 동등성이 없는 항목 — `Page` 가 제약 없는 Item 도 담는다는 계약을 컴파일 단계에서 고정한다.
private struct OpaqueItem {
    let handler: () -> Void
}

@Suite("Page 다음 장 계산")
struct PageTests {
    @Test("첫 장 요청은 page 0 에서 시작한다")
    func firstStartsAtPageZero() {
        let request = PageRequest.first(pageSize: 7)

        #expect(request == PageRequest(page: 0, pageSize: 7))
    }

    @Test("마지막 장이면 다음 요청이 없다")
    func lastPageHasNoNext() {
        let page = Page(items: [1, 2, 3], page: 0, pageSize: 20, hasNext: false)

        #expect(page.next == nil)
    }

    @Test("다음 장이 있으면 page 만 1 늘고 pageSize 는 유지된다")
    func nextAdvancesPageKeepingSize() {
        let page = Page(items: [1, 2, 3], page: 3, pageSize: 7, hasNext: true)

        let next = page.next

        #expect(next == PageRequest(page: 4, pageSize: 7))
    }

    @Test("pageSize 가 0 이하면 다음 장을 만들지 않는다", arguments: [0, -1])
    func nextStopsWhenPageSizeIsNotPositive(pageSize: Int) {
        let page = Page(items: [Int](), page: 0, pageSize: pageSize, hasNext: true)

        #expect(page.next == nil)
    }

    @Test("첫 장에서 다음 장으로 연속된 page 를 만든다")
    func firstThenNextWalksConsecutivePages() {
        let first = PageRequest.first(pageSize: 20)
        let page = Page(items: [1, 2, 3], page: first.page, pageSize: first.pageSize, hasNext: true)

        let next = page.next

        #expect(first.page == 0)
        #expect(next?.page == 1)
    }

    @Test("항목이 비어도 hasNext 가 참이면 다음 장을 준다")
    func emptyPageStillAdvancesWhenHasNext() {
        let page = Page(items: [Int](), page: 0, pageSize: 20, hasNext: true)

        #expect(page.next != nil)
    }

    @Test("같은 값은 동등하고 page 가 다르면 동등하지 않다")
    func equatableComparesFields() {
        let page = Page(items: [1, 2], page: 0, pageSize: 20, hasNext: true)
        let same = Page(items: [1, 2], page: 0, pageSize: 20, hasNext: true)
        let differentPage = Page(items: [1, 2], page: 1, pageSize: 20, hasNext: true)

        #expect(page == same)
        #expect(page != differentPage)
    }

    @Test("Equatable 이 아닌 항목도 담을 수 있다")
    func holdsNonEquatableItems() {
        let page = Page(items: [OpaqueItem(handler: {})], page: 0, pageSize: 20, hasNext: false)

        #expect(page.items.count == 1)
    }
}
