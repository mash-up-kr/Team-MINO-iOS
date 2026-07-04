import Testing
import MapUI
import MVITestSupport
@testable import Feature

@MainActor
struct MapHomeReducerTests {
    private func makeStore(
        state: MapHomeState = .seoulSample()
    ) -> TestStore<MapHomeState, MapHomeAction, MapHomeNav> {
        TestStore(state, reduce: mapHomeReducer())
    }

    /// 검증 핵심 경로: 마커 탭 이벤트 → 화면 전환(NavigationEffect).
    @Test("마커 탭은 상세 화면 전환을 낸다")
    func tapMarker_navigatesToDetail() async {
        let store = makeStore()
        await store.send(.map(.didTapMarker(id: "city-hall")))
        store.receiveNavigation(.goToMarkerDetail("city-hall"))
        store.finish()
    }

    /// 좌표 이벤트가 Store 상태까지 도달함을 증명.
    @Test("지도 빈 곳 탭은 lastTappedCoordinate 를 갱신한다")
    func tapMap_updatesLastTapped() async {
        let store = makeStore()
        let coordinate = MapCoordinate(latitude: 37.1, longitude: 127.2)
        await store.send(.map(.didTap(coordinate))) {
            $0.lastTappedCoordinate = coordinate
        }
        store.finish()
    }

    /// 카메라 idle 이벤트가 state.camera 를 그대로(줌 포함) 갱신한다.
    @Test("카메라 idle 은 카메라 전체(좌표+줌)를 반영한다")
    func idle_updatesCamera() async {
        let store = makeStore()
        let moved = MapCameraPosition(coordinate: MapCoordinate(latitude: 35.0, longitude: 129.0), zoom: 15)
        await store.send(.map(.didIdleAt(moved))) {
            $0.camera = moved
        }
        store.finish()
    }
}

/// navigation 라우팅 검증 — Coordinator.handle 직접 호출(구독과 분리, 결정적).
@MainActor
struct MapCoordinatorTests {
    @Test("goToMarkerDetail 은 상세 라우트를 push 한다")
    func handle_pushesDetail() {
        let coordinator = MapCoordinator()
        coordinator.handle(.goToMarkerDetail("gangnam"))
        #expect(coordinator.path == [.markerDetail("gangnam")])
    }
}
