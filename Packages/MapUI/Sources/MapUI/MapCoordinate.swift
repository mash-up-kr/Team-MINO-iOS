/// 지도 위 한 지점의 좌표. GoogleMaps 의 `CLLocationCoordinate2D` 가 경계 밖으로 새지 않도록
/// MapUI 가 노출하는 순수 value type. (플랫폼 비의존 — 테스트 호스트에서도 컴파일된다)
public struct MapCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
