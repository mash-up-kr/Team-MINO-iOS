import Foundation
import Testing
import Domain
@testable import FeatureArchive

@Suite("방 상세 업종 칩")
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

    @Test("칩 목록은 담긴 장소의 업종에서 만들어진다 — 고정 3개가 아니다")
    func make_derivesFromPins() {
        let pins = [pin("a", category: "카페"), pin("b", category: "전시회"), pin("c", category: "카페")]

        #expect(RoomDetailCategoryList.make(from: pins) == ["전체", "카페", "전시회"])
    }

    @Test("업종이 없는 장소만 있으면 칩은 '전체' 하나다")
    func make_noCategory() {
        #expect(RoomDetailCategoryList.make(from: [pin("a", category: nil)]) == ["전체"])
    }

    @Test("칩은 처음 나온 순서를 지킨다 — 가나다 정렬하지 않는다")
    func make_keepsFirstSeenOrder() {
        let pins = [pin("a", category: "음식점"), pin("b", category: "카페")]

        #expect(RoomDetailCategoryList.make(from: pins) == ["전체", "음식점", "카페"])
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
