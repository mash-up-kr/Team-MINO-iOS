/// 지도가 잡아야 할 카메라.
///
/// 단일 위치(``MapCameraPosition``)로 끝내지 않는 이유는 "마커가 전부 보이게" 라는 요구가
/// 중심·줌을 **뷰 크기까지 알아야** 낼 수 있기 때문이다. 그 계산을 순수 함수로 흉내내면
/// 지도 padding(바텀시트가 가리는 높이)과 화면 비율을 다시 구현해야 해서 SDK 에 맡긴다.
public enum MapCamera: Equatable, Sendable {
    /// 지정한 중심·줌으로 이동한다.
    case position(MapCameraPosition)
    /// 주어진 좌표가 모두 보이도록 SDK 가 중심·줌을 계산한다.
    ///
    /// `coordinates` 가 비면 적용하지 않는다 — 맞출 대상이 없는데 카메라를 건드리면
    /// 지구 전체가 잡힌다. 호출부가 이 경우 ``position(_:)`` 으로 폴백한다.
    /// `padding` 은 좌표들이 화면 가장자리에 붙지 않도록 두는 여백(pt)이다.
    case fit(coordinates: [MapCoordinate], padding: Double)
}
