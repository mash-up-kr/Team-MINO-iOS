/// 지도 카메라 위치(중심 좌표 + 줌 레벨). GoogleMaps 의 `GMSCameraPosition` 을 감싸는 순수 value type.
public struct MapCameraPosition: Equatable, Sendable {
    public let coordinate: MapCoordinate
    public let zoom: Float

    public init(coordinate: MapCoordinate, zoom: Float) {
        self.coordinate = coordinate
        self.zoom = zoom
    }
}
