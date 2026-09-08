/// 지도 카메라 위치(중심 좌표 + 줌 레벨). GoogleMaps 의 `GMSCameraPosition` 을 감싸는 순수 value type.
public struct MapCameraPosition: Equatable, Sendable {
    public let coordinate: MapCoordinate
    public let zoom: Float

    /// **같은 자리로 다시** 옮겨 달라는 요청을 앞선 요청과 구별하는 번호.
    ///
    /// 지도는 이미 적용한 카메라와 같은 값이 다시 들어오면 무시한다(``MapView`` 의 `appliedCamera`)
    /// — 그래야 화면이 다시 그려질 때마다 사용자가 옮겨 둔 지도를 뺏지 않는다. 그런데 그 규칙은
    /// **현위치 버튼**을 망가뜨린다: 버튼을 눌러 내 위치로 간 뒤 지도를 손으로 옮기고 같은 버튼을
    /// 다시 누르면, 좌표·줌이 직전과 같아 "이미 적용함" 으로 걸러져 아무 일도 일어나지 않는다.
    /// 손으로 옮긴 것은 카메라 값이 아니라 지도 내부 상태만 바꾸기 때문이다.
    ///
    /// 그래서 요청마다 번호를 올려 값 자체를 다르게 만든다. 표시에는 전혀 쓰이지 않는다.
    /// 기본값 `0` 은 "되풀이될 일이 없는 이동"(진입 카메라·핀 맞춤 폴백)이라는 뜻이다.
    ///
    /// Android 도 같은 증상을 실기기에서 확인하고 `mapCenterRequestId` 로 같은 해법을 썼다.
    public let requestID: Int

    public init(coordinate: MapCoordinate, zoom: Float, requestID: Int = 0) {
        self.coordinate = coordinate
        self.zoom = zoom
        self.requestID = requestID
    }
}
