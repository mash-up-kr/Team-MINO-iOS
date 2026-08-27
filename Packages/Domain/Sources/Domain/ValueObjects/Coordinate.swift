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
