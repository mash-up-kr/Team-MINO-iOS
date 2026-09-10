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

/// 핀 아트의 색 축 13종 (Figma `character/Pin` 의 `color` 배리언트).
///
/// rawValue 는 에셋 이름의 **접미사**다 — ``assetName(selected:)`` 가 상태 접두사와 이어 붙여
/// `pinDefaultRed`·`pinActiveRed` 처럼 완성한다. `plain` 만 Figma 배리언트 이름(`black`)을 따라 `"Black"` 이다.
///
/// > 어떤 색이 어느 방인지는 MapUI 가 알지 않는다 — 방 색(`RoomColor`)은 Domain 값이고 MapUI 는
/// > Domain 을 보지 않는다. 그 이음은 `PlaceMapUI` 의 `PlaceMap.markerColor(for:)` 가 한다.
public enum MapMarkerColor: String, CaseIterable, Hashable, Sendable {
    /// 색을 고르지 않은 방. 회색 실루엣이다(Figma `color=black`).
    case plain = "Black"
    case red = "Red"
    case redOrange = "RedOrange"
    case orange = "Orange"
    case lime = "Lime"
    case green = "Green"
    case cyan = "Cyan"
    case lightBlue = "LightBlue"
    case blue = "Blue"
    case violet = "Violet"
    case purple = "Purple"
    case pink = "Pink"
    case brown = "Brown"

    /// 이 색·상태의 에셋 이름(`Resources/MapMarkers.xcassets`).
    ///
    /// 선택 핀은 `pinActive`(56×61, 얼굴·소품이 보이는 큰 핀), 기본 핀은 `pinDefault`(42×48, 색
    /// 실루엣) — Figma `mode` 배리언트의 `on`/`off` 다. **선택 핀에도 색 축이 있다** — 배리언트 id 가
    /// `color=red, mode=on` 이다.
    ///
    /// 이름을 조립하므로 조합 하나가 어긋나면 그 색·상태만 조용히 빈다 — 26 조합을 전부 짚는 테스트가
    /// `PlaceMapUITests/MapMarkerArtTests` 에 있다(MapUI 테스트는 macOS 호스트라 `UIImage` 가 없다).
    public func assetName(selected: Bool) -> String {
        (selected ? "pinActive" : "pinDefault") + rawValue
    }
}

/// 마커가 무엇을 가리키는가. 장소 하나(`pin`)이거나, 겹친 여러 장소를 묶은 것(`cluster`)이다.
///
/// 그리는 방식이 갈린다 — 핀은 **에셋 아트**(``MapMarkerColor``)이고 클러스터는 **코드로 그린 원**이라
/// 채움색을 `Color` 로 받는다. 각 종류가 자기 그림에 필요한 값만 든다 — 한 원천(방 색)에서 나온 두
/// 값을 함께 들면 한쪽은 늘 죽어 있다.
///
/// PRD 「커스텀 핀 마커」의 4가지 형태 중 `기본 핀`·`선택 핀`은 ``MapMarkerStyle/isSelected`` 가,
/// `클러스터 1~99`·`클러스터 100+` 는 이 값이 가른다.
public enum MapMarkerKind: Equatable, Hashable, Sendable {
    /// 장소 하나. 소속 방의 색으로 그린다.
    case pin(MapMarkerColor)
    /// 겹친 장소 묶음. `count` 는 묶인 장소 수, `tint` 는 원의 채움색이다.
    ///
    /// 채움색을 RGB 숫자가 아니라 SwiftUI `Color` 로 받는 이유: 호출부가 디자인 토큰(`Color.mh*`)을
    /// 그대로 넘길 수 있어 팔레트 hex 가 두 곳에 복제되지 않는다. `Color` 의 `==` 는 같은 방식으로
    /// 만든 값끼리 안정적으로 참이라(에셋 색은 이름+번들 비교) 마커 diff 가 매 업데이트마다 흔들리지 않는다.
    case cluster(count: Int, tint: Color)

    /// 클러스터에 표시할 카운트. 99까지는 그 수를, 100 이상은 `100+` 를 쓴다.
    ///
    /// PRD [SYS-004] Flow C 의 두 갈래 — *"1~99개는 `50+` 식 숫자 표기 클러스터, 100개 이상은
    /// `100+` 클러스터"*. 그 "`50+` 식" 은 **예시 표기**이므로 실제 수를 쓴다. 아바타 카운터
    /// (`MHAvatarCountBadge`, 상한 99)와 상한이 다른 것은 PRD 가 이쪽만 100 으로 적었기 때문이다.
    ///
    /// **규칙은 여기 하나다** — 그림을 그리는 `MapView` 와 묶음을 만드는 `PlaceMap` 이 같은 함수를
    /// 본다. 두 벌로 두면 한쪽만 고쳐도 컴파일이 통과한다.
    public static func clusterCountText(_ count: Int) -> String {
        count >= 100 ? "100+" : "\(count)"
    }
}

/// 마커의 겉모습. **종류(색 포함)·선택 여부만** 담고 그림 자체는 `MapView` 가 만든다 —
/// `UIImage` 는 순수 value type 이 아니고 테스트 호스트(macOS)에서 쓸 수 없어 경계 밖으로 내보내지 않는다.
///
/// `Hashable` 이라 `MapView` 의 아이콘 캐시 키로 그대로 쓰인다 — 핀 그림은 색 × 상태(최대 26장),
/// 클러스터 그림은 카운트 × 색 종류만큼만 캐시된다.
public struct MapMarkerStyle: Equatable, Hashable, Sendable {
    /// 장소 하나인가 묶음인가, 어떤 색인가.
    public let kind: MapMarkerKind
    /// 선택된 마커인가. 선택 핀은 다른 아트(`pinActive*`, 방 색 유지)로, 다른 마커보다 위에 그려진다.
    ///
    /// 클러스터는 선택되지 않는다 — 어느 장소인지 정해지지 않아 상세를 열 수 없으므로 호출부가
    /// 항상 `false` 로 보내고, 그림도 이 값을 읽지 않는다.
    public let isSelected: Bool

    public init(kind: MapMarkerKind = .pin(.plain), isSelected: Bool = false) {
        self.kind = kind
        self.isSelected = isSelected
    }

    /// 방 색이 없을 때 클러스터 원의 채움색 — 시안의 색 없는 핀(`pinDefaultBlack`)이 쓰는 `#DBDCDF`.
    /// 핀은 이 값을 쓰지 않는다: 색 없는 핀은 ``MapMarkerColor/plain`` 아트 자체가 회색이다.
    public static let defaultTint = Color(red: 0xDB / 255, green: 0xDC / 255, blue: 0xDF / 255)

    /// 색을 지정하지 않은 핀.
    public static let `default` = MapMarkerStyle()
}
