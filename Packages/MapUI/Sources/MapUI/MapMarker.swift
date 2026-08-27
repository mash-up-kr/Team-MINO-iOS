import SwiftUI

/// 지도에 표시하는 마커. `id` 로 구분하며, 탭 이벤트(`MapEvent.didTapMarker`)에 이 `id` 가 실려 되돌아온다.
public struct MapMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let coordinate: MapCoordinate
    public let title: String?
    /// 마커를 어떻게 그릴지. 이 값이 바뀌면 `MarkerDiff` 가 `updated` 로 잡아 아이콘을 다시 적용한다.
    public let style: MapMarkerStyle

    public init(
        id: String,
        coordinate: MapCoordinate,
        title: String? = nil,
        style: MapMarkerStyle = .default
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.style = style
    }
}

/// 마커의 겉모습. **색과 선택 여부만** 담고 그림 자체는 `MapView` 가 만든다 —
/// `UIImage` 는 순수 value type 이 아니고 테스트 호스트(macOS)에서 쓸 수 없어 경계 밖으로 내보내지 않는다.
///
/// 색을 RGB 숫자가 아니라 SwiftUI `Color` 로 받는 이유: 호출부가 디자인 토큰(`Color.mh*`)을 그대로
/// 넘길 수 있어 팔레트 hex 가 두 곳에 복제되지 않는다. `Color` 의 `==` 는 같은 방식으로 만든 값끼리
/// 안정적으로 참이라(에셋 색은 이름+번들 비교) 마커 diff 가 매 업데이트마다 흔들리지 않는다.
public struct MapMarkerStyle: Equatable, Hashable, Sendable {
    /// 마커에서 색이 들어가는 자리(핀 안쪽 원)의 색.
    ///
    /// > 선택 마커는 이 값을 쓰지 않는다. 시안의 선택 아이콘은 색 슬롯 없이 고정색(검정 머리 +
    /// > 흰 눈)이라 방마다 달라지지 않는다. 값을 무시할 뿐 지우지는 않는다 — 디자인이 선택
    /// > 상태에도 방 색을 넣기로 하면 여기만 다시 읽으면 된다.
    public let tint: Color
    /// 선택된 마커인가. 선택 마커는 다른 그림으로, 다른 마커보다 위에 그려진다.
    public let isSelected: Bool

    public init(tint: Color = defaultTint, isSelected: Bool = false) {
        self.tint = tint
        self.isSelected = isSelected
    }

    /// 색을 고르지 않은 마커의 원 색(시안 `#DBDCDF`). 호출부가 "색 없음"을 그릴 때 쓴다.
    public static let defaultTint = Color(red: 0xDB / 255, green: 0xDC / 255, blue: 0xDF / 255)

    /// 색을 지정하지 않았을 때의 마커.
    public static let `default` = MapMarkerStyle()
}
