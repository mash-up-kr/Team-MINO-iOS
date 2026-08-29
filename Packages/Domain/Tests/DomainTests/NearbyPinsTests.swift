import Foundation
import Testing
@testable import Domain

struct NearbyPinsTests {
    private let origin = Coordinate(latitude: 37.5443, longitude: 127.0557)

    private func pin(_ id: String, metersAway: Double, createdAt: Date = Date(timeIntervalSince1970: 0)) -> Pin {
        PinFixture.pin(
            id: id,
            createdAt: createdAt,
            place: PinFixture.place(id: id, coordinate: north(of: origin, meters: metersAway))
        )
    }

    @Test("반경 상수는 시안 004-1 ⑥ 의 3km")
    func radius() {
        #expect(NearbyPins.radiusInMeters == 3_000)
    }

    @Test("반경 안의 장소만 남기고 가까운 순으로 세운다")
    func sortsAndFilters() {
        let pins = [
            pin("far", metersAway: 5_000),
            pin("mid", metersAway: 2_000),
            pin("near", metersAway: 100),
            pin("veryFar", metersAway: 30_000),
        ]

        let result = NearbyPins.sortedByDistance(pins, from: origin)

        #expect(result.map(\.id.value) == ["near", "mid"])
    }

    // "정확히 3km" 는 부동소수로 재현되지 않는다 — 자오선 위로 3,000m 를 만들어도 Haversine 은
    // 3000.0000000002 를 낸다(도↔라디안 환산 오차, 0.2 나노미터). 반경 판정을 그 자리에 걸면
    // 테스트가 libm 구현에 따라 뒤집히므로 경계는 두 축으로 나눠 본다:
    // 거리 계산이 3,000m 를 ±1mm 로 맞추는지(``CoordinateDistanceTests/meridian``)와,
    // 미터 단위 판정(3km 안은 포함 / 3km 를 넘으면 제외)이 맞는지(아래).
    @Test("3km 안의 장소는 남는다")
    func insideRadius() {
        let result = NearbyPins.sortedByDistance([pin("edge", metersAway: 2_999)], from: origin)
        #expect(result.map(\.id.value) == ["edge"])
    }

    @Test("3km 를 1m 넘으면 빠진다")
    func outsideRadius() {
        let result = NearbyPins.sortedByDistance([pin("edge", metersAway: 3_001)], from: origin)
        #expect(result.isEmpty)
    }

    @Test("기준점과 같은 자리도 반경 안이다")
    func atOrigin() {
        let result = NearbyPins.sortedByDistance([pin("here", metersAway: 0)], from: origin)
        #expect(result.map(\.id.value) == ["here"])
    }

    @Test("거리가 같으면 최신 저장이 앞이다 — 거리만으로는 순서가 정해지지 않는다")
    func tieBreaksByRecency() {
        let old = pin("old", metersAway: 1_000, createdAt: Date(timeIntervalSince1970: 100))
        let new = pin("new", metersAway: 1_000, createdAt: Date(timeIntervalSince1970: 200))

        #expect(NearbyPins.sortedByDistance([old, new], from: origin).map(\.id.value) == ["new", "old"])
        #expect(NearbyPins.sortedByDistance([new, old], from: origin).map(\.id.value) == ["new", "old"])
    }

    @Test("반경 안에 아무것도 없으면 빈 목록")
    func noneInRadius() {
        #expect(NearbyPins.sortedByDistance([pin("far", metersAway: 4_000)], from: origin).isEmpty)
    }

    @Test("빈 목록은 그대로 빈 목록")
    func emptyInput() {
        #expect(NearbyPins.sortedByDistance([], from: origin).isEmpty)
    }
}
