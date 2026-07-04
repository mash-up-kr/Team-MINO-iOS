/// 지도가 바깥(Feature)으로 던지는 사용자 이벤트. MapUI 는 이 값을 `onEvent` 클로저로 전달할 뿐,
/// MVI·Coordinator 를 알지 못한다. Feature 가 이 이벤트를 `store.send(.map(event))` 로 연결한다.
public enum MapEvent: Equatable, Sendable {
    /// 마커 탭. 마커 `id` 가 실려 온다.
    case didTapMarker(id: String)
    /// 지도 빈 곳 탭. 탭한 좌표가 실려 온다.
    case didTap(MapCoordinate)
    /// 카메라 이동이 멈춘 시점의 카메라(중심 좌표 + 줌). 좌표만 싣으면 줌이 유실돼
    /// 지도에 되먹일 때 줌이 튕기므로 전체 위치를 싣는다.
    case didIdleAt(MapCameraPosition)
}
