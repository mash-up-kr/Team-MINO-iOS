import MapUI
import MVI

/// 지도 홈 화면 상태. 순수 value type(MapUI)만 담아 플랫폼 비의존 — reduce 테스트가 macOS 호스트에서 돈다.
public struct MapHomeState: Equatable {
    public var camera: MapCameraPosition
    public var markers: [MapMarker]
    /// 지도 빈 곳 탭 좌표 — 좌표 이벤트가 Store 까지 도달했음을 증명하는 시범용 필드.
    public var lastTappedCoordinate: MapCoordinate?

    public init(
        camera: MapCameraPosition,
        markers: [MapMarker] = [],
        lastTappedCoordinate: MapCoordinate? = nil
    ) {
        self.camera = camera
        self.markers = markers
        self.lastTappedCoordinate = lastTappedCoordinate
    }

    /// 데모용 초기 상태(서울 중심 + 마커 2개). 도메인 데이터 연동 시 제거한다.
    public static func seoulSample() -> MapHomeState {
        MapHomeState(
            camera: MapCameraPosition(
                coordinate: MapCoordinate(latitude: 37.5666, longitude: 126.9784),
                zoom: 12
            ),
            markers: [
                MapMarker(id: "city-hall", coordinate: MapCoordinate(latitude: 37.5663, longitude: 126.9779), title: "서울시청"),
                MapMarker(id: "gangnam", coordinate: MapCoordinate(latitude: 37.4979, longitude: 127.0276), title: "강남역"),
            ]
        )
    }
}

public enum MapHomeAction: Equatable {
    /// 지도(MapUI)가 던진 이벤트를 그대로 받는 진입 Action.
    case map(MapEvent)
}

/// 화면 전환 의도. `Store` 가 `observeNavigation` 으로 Coordinator 에 전달한다.
public enum MapHomeNav: Equatable, Sendable {
    case goToMarkerDetail(String)
}

public typealias MapHomeStore = Store<MapHomeState, MapHomeAction, MapHomeNav>

/// 순수 reduce. 아직 UseCase 가 없어(지도 데이터가 도메인이 아님) 의존성을 받지 않는다.
/// 지도 마커가 도메인 데이터가 되면 `mapHomeReducer(useCase:)` 로 확장한다.
public func mapHomeReducer() -> (inout MapHomeState, MapHomeAction) -> Effect<MapHomeAction, MapHomeNav> {
    { state, action in
        switch action {
        case .map(.didTapMarker(let id)):
            return .navigate(.goToMarkerDetail(id))   // ← 검증 핵심: 지도 이벤트 → 화면 전환
        case .map(.didTap(let coordinate)):
            state.lastTappedCoordinate = coordinate
            return .none
        case .map(.didIdleAt(let camera)):
            state.camera = camera   // 지도 카메라를 그대로 반영(줌 포함) — 되먹임 시 재적용 스킵됨
            return .none
        }
    }
}
