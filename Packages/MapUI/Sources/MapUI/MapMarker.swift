/// 지도에 표시하는 마커. `id` 로 구분하며, 탭 이벤트(`MapEvent.didTapMarker`)에 이 `id` 가 실려 되돌아온다.
public struct MapMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: MapCoordinate
    public let title: String?

    public init(id: String, coordinate: MapCoordinate, title: String? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
    }
}
