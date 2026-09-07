import Foundation
import Testing
import Domain
@testable import FeatureArchive

@Suite("카테고리 칩")
struct RoomDetailCategoryTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, category: String?, commentCount: Int = 0, daysAgo: Double = 0) -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            placeCategory: category,
            commentCount: commentCount,
            createdAt: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    // PRD 「카테고리 필터」 = 3종 고정, 기본값 `전체`. 비목표에도 "저장 값 기반 동적 카테고리
    // 생성" 이 명시돼 있어, 방에 무엇이 담겼든 칩은 이 셋이다.
    @Test("칩은 전체·카페·음식점 3종 고정이다 — 담긴 장소와 무관하다")
    func items_areFixedThree() {
        #expect(RoomDetailCategoryList.items == ["전체", "카페", "음식점"])
    }

    @Test("첫 칩이 기본 선택값 '전체' 다")
    func items_startWithAll() {
        #expect(RoomDetailCategoryList.items.first == RoomDetailCategoryList.all)
    }

    // 칩에 없는 업종("전시회")의 장소는 `전체` 에서만 보인다 — 걸러 낼 칩 자체가 없다.
    @Test("칩에 없는 업종의 장소는 전체에서만 보인다")
    func filter_categoryOutsideChips() {
        let pins = [pin("a", category: "카페"), pin("b", category: "전시회")]

        #expect(RoomDetailCategoryList.filter(pins, by: "전체").count == 2)
        #expect(RoomDetailCategoryList.filter(pins, by: "음식점").isEmpty)
    }

    @Test("'전체' 는 거르지 않는다")
    func filter_all() {
        let pins = [pin("a", category: "카페"), pin("b", category: "전시회")]

        #expect(RoomDetailCategoryList.filter(pins, by: "전체").map(\.id) == pins.map(\.id))
    }

    @Test("업종을 고르면 그 업종만 남는다 — 업종 없는 장소는 빠진다")
    func filter_byCategory() {
        let pins = [pin("a", category: "카페"), pin("b", category: "전시회"), pin("c", category: nil)]

        #expect(RoomDetailCategoryList.filter(pins, by: "카페").map(\.id.value) == ["a"])
    }
}

@Suite("코멘트순 정렬")
struct RoomDetailCommentSortTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, commentCount: Int, daysAgo: Double = 0) -> Pin {
        PinFixture.pin(
            id: PinID(id), roomID: "r1", category: .worthVisiting,
            title: id, address: id, commentCount: commentCount,
            createdAt: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    @Test("코멘트 수 기준 상위 30% 만 남기고 많은 순으로 낸다")
    func topThirtyPercent() {
        let pins = (0..<10).map { pin("p\($0)", commentCount: $0) }   // 0..9

        let result = RoomDetailSorting.apply(.comment, to: pins, now: now)

        #expect(result.count == 3)                                     // 10 * 0.3
        #expect(result.map(\.commentCount) == [9, 8, 7])
    }

    @Test("코멘트 수가 같으면 최신 저장이 앞이다 — 순서가 흔들리지 않게")
    func tieBreaksByRecency() {
        let pins = [
            pin("old", commentCount: 5, daysAgo: 10),
            pin("new", commentCount: 5, daysAgo: 1),
        ]

        let result = RoomDetailSorting.apply(.comment, to: pins, now: now)

        #expect(result.first?.id.value == "new")
    }

    @Test("장소가 없으면 빈 목록이다")
    func empty() {
        #expect(RoomDetailSorting.apply(.comment, to: [], now: now).isEmpty)
    }
}
