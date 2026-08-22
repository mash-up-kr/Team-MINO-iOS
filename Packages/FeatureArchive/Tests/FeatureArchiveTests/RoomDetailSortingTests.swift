import Foundation
import Testing
import Domain
@testable import FeatureArchive

struct RoomDetailSortingTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, daysAgo: Double) -> Pin {
        Pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            createdAt: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    private var pins: [Pin] {
        (0..<10).map { pin("p\($0)", daysAgo: Double($0) * 5) }
    }

    @Test("전체는 원본을 그대로 낸다")
    func all() {
        #expect(RoomDetailSorting.apply(.all, to: pins, now: now).map(\.id) == pins.map(\.id))
    }

    @Test("꾹 Pick 은 가장 오래된 상위 30% 를 오래된 순으로 낸다")
    func pick() {
        let result = RoomDetailSorting.apply(.pick, to: pins, now: now)
        #expect(result.map(\.id.value) == ["p9", "p8", "p7"])
    }

    @Test("꾹 Pick 은 목록이 짧아도 최소 1건은 남긴다")
    func pickKeepsAtLeastOne() {
        let single = [pin("only", daysAgo: 3)]
        #expect(RoomDetailSorting.apply(.pick, to: single, now: now).count == 1)
    }

    @Test("최신순은 14일 이내만 최신 순으로 낸다")
    func latest() {
        let result = RoomDetailSorting.apply(.latest, to: pins, now: now)
        #expect(result.map(\.id.value) == ["p0", "p1", "p2"])
    }

    @Test("최신순은 경계(정확히 14일 전)를 포함한다")
    func latestIncludesBoundary() {
        let boundary = [pin("edge", daysAgo: 14)]
        #expect(RoomDetailSorting.apply(.latest, to: boundary, now: now).count == 1)
    }

    @Test("거리순·코멘트순은 계산할 수 없어 원본을 그대로 낸다")
    func unsupportedSortsPassThrough() {
        for sort in [RoomDetailSort.distance, .comment] {
            #expect(RoomDetailSorting.apply(sort, to: pins, now: now).map(\.id) == pins.map(\.id))
        }
    }

    @Test("빈 목록은 어떤 정렬에도 빈 목록이다")
    func emptyInput() {
        for sort in RoomDetailSort.allCases {
            #expect(RoomDetailSorting.apply(sort, to: [], now: now).isEmpty)
        }
    }
}
