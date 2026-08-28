import Foundation
import Testing
import Domain
@testable import FeatureArchive

struct RoomDetailSortingTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private let origin = Coordinate(latitude: 37.5443, longitude: 127.0557)

    private func pin(_ id: String, daysAgo: Double, metersAway: Double = 0) -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            coordinate: PinFixture.coordinate(metersAway, northOf: origin),
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

    @Test("최신순은 전체를 최신 순으로 재정렬한다 — 기간으로 걸러내지 않는다")
    func latest() {
        let result = RoomDetailSorting.apply(.latest, to: pins, now: now)
        #expect(result.map(\.id.value) == (0..<10).map { "p\($0)" })
        #expect(result.count == pins.count)
    }

    // MARK: - 거리순 (004-1 ⑥ "내 기준 3km반경 내에 있는 게시물 노출")

    /// 반경 밖 1건(5km) + 안 2건. 입력 순서를 일부러 거리와 어긋나게 둬 재정렬을 확인한다.
    private var distancePins: [Pin] {
        [
            pin("far", daysAgo: 1, metersAway: 5_000),
            pin("mid", daysAgo: 2, metersAway: 2_000),
            pin("near", daysAgo: 3, metersAway: 300),
        ]
    }

    @Test("거리순은 3km 반경 안만 남겨 가까운 순으로 세운다")
    func distance() {
        let result = RoomDetailSorting.apply(.distance, to: distancePins, now: now, from: origin)
        #expect(result.map(\.id.value) == ["near", "mid"])
    }

    @Test("기준점을 못 받았으면 원본 순서 그대로 — 3km 와 무관한 목록을 거리순으로 내보이지 않는다")
    func distanceWithoutOrigin() {
        let pins = distancePins
        #expect(RoomDetailSorting.apply(.distance, to: pins, now: now).map(\.id) == pins.map(\.id))
    }

    @Test("거리순만 기준점을 쓴다 — 다른 정렬은 좌표가 있어도 결과가 같다")
    func originIgnoredByOtherSorts() {
        for sort in RoomDetailSort.allCases where sort != .distance {
            #expect(
                RoomDetailSorting.apply(sort, to: pins, now: now, from: origin).map(\.id)
                    == RoomDetailSorting.apply(sort, to: pins, now: now).map(\.id)
            )
        }
    }

    @Test("빈 목록은 어떤 정렬에도 빈 목록이다")
    func emptyInput() {
        for sort in RoomDetailSort.allCases {
            #expect(RoomDetailSorting.apply(sort, to: [], now: now, from: origin).isEmpty)
        }
    }
}
