import Foundation

/// 위경도 좌표. 식별자 없이 값 자체로 동등성을 비교하는 Value Object 이며 불변이다.
///
/// `CLLocationCoordinate2D` 를 쓰지 않는다 — CoreLocation 의존이 Domain 에 들어오면
/// `Domain 은 의존 0` 규칙이 깨진다. 지도 SDK 타입으로의 변환은 `MapUI` 가 담당한다.
public struct Coordinate: Equatable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public extension Coordinate {
    /// 두 좌표 사이의 대권(great-circle) 거리(m). 지구를 구로 근사하는 Haversine 공식.
    ///
    /// `CLLocation.distance(from:)` 을 쓰지 않는다 — CoreLocation 은 Domain 이 볼 수 없는
    /// 프레임워크다(위 타입 주석과 같은 이유). 그쪽은 회전타원체 모델이라 더 정확하지만,
    /// 구 근사의 오차는 3km 거리에서 십수 m 수준으로 휴대폰 측위 오차보다 작다.
    /// 반경 경계에 정확히 걸친 장소의 포함 여부가 갈릴 수는 있으나, 그만한 정밀도는
    /// 위치 자체가 제공하지 못한다.
    func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLatitude = (other.latitude - latitude) * .pi / 180
        let deltaLongitude = (other.longitude - longitude) * .pi / 180

        let haversine = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        // 부동소수 오차로 1 을 아주 살짝 넘으면 asin 이 NaN 을 낸다 — 지구 반대편에서만 닿는 값이라 잘라 낸다.
        return 2 * Self.earthRadiusInMeters * asin(min(1, sqrt(haversine)))
    }

    /// 지구 평균 반지름(m). IUGG 가 정의한 산술평균 반지름 R₁.
    private static let earthRadiusInMeters = 6_371_008.8
}
