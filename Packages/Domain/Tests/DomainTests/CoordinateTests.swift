import Foundation
import Testing
@testable import Domain

/// `Coordinate` 가 쓰는 지구 평균 반지름(m). 구현과 같은 값이라야 "북쪽으로 정확히 N미터" 를 만들 수 있다.
let earthRadiusInMeters = 6_371_008.8

/// 자오선(같은 경도) 위로 `meters` 만큼 북쪽인 좌표.
/// 경도가 같으면 Haversine 이 `R·Δφ` 로 떨어져 원하는 거리를 정확히 지정할 수 있다.
func north(of origin: Coordinate, meters: Double) -> Coordinate {
    Coordinate(
        latitude: origin.latitude + meters / earthRadiusInMeters * 180 / .pi,
        longitude: origin.longitude
    )
}

struct CoordinateDistanceTests {
    private let seongsu = Coordinate(latitude: 37.5443, longitude: 127.0557)

    @Test("같은 좌표 사이는 0m")
    func zero() {
        #expect(seongsu.distance(to: seongsu) == 0)
    }

    @Test("거리는 어느 쪽에서 재도 같다")
    func symmetric() {
        let other = Coordinate(latitude: 37.4979, longitude: 127.0276)
        #expect(seongsu.distance(to: other) == other.distance(to: seongsu))
    }

    @Test("자오선 위 3km 는 3,000m 로 계산된다")
    func meridian() {
        #expect(abs(seongsu.distance(to: north(of: seongsu, meters: 3_000)) - 3_000) < 0.001)
    }

    @Test("서울시청↔강남역은 약 8.78km — 회전타원체 기준 값과 어긋나지 않는다")
    func knownDistance() {
        // 구 근사(Haversine) 8,778.02m. CoreLocation(회전타원체) 값과 10m 안쪽에서 만난다.
        let cityHall = Coordinate(latitude: 37.5663, longitude: 126.9779)
        let gangnam = Coordinate(latitude: 37.4979, longitude: 127.0276)
        #expect(abs(cityHall.distance(to: gangnam) - 8_778.02) < 1)
    }

    @Test("지구 반대편도 NaN 없이 계산된다")
    func antipode() {
        let antipode = Coordinate(latitude: -seongsu.latitude, longitude: seongsu.longitude - 180)
        let distance = seongsu.distance(to: antipode)
        #expect(!distance.isNaN)
        #expect(abs(distance - .pi * earthRadiusInMeters) < 1)
    }
}
