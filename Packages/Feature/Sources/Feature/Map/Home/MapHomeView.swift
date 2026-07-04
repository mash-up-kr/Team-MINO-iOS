#if os(iOS)
import SwiftUI
import MapUI

/// 지도 flow 의 진입 View. NavigationStack(path)을 Coordinator 에 바인딩하고,
/// 지도 이벤트를 `store.send(.map($0))` 로 연결한다(SDK→MVI 이음매).
/// GoogleMaps(UIViewRepresentable)는 iOS 전용 → 파일 전체를 `#if os(iOS)` 로 가둔다.
public struct MapHomeView: View {
    private let coordinator: MapCoordinator
    @State private var store: MapHomeStore?

    public init(coordinator: MapCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            content
                .navigationDestination(for: MapRoute.self) { route in
                    switch route {
                    case .markerDetail(let id):
                        MapMarkerDetailView(markerID: id)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            MapHomeContentView(store: store)
        } else {
            ProgressView()
                .task { store = coordinator.makeHomeStore() }   // store 1회 lazy 생성
        }
    }
}

/// 지도 표시 + 이벤트 전달. store 상태를 읽어 그린다.
struct MapHomeContentView: View {
    let store: MapHomeStore

    var body: some View {
        MapView(
            camera: store.state.camera,
            markers: store.state.markers,
            onEvent: { store.send(.map($0)) }   // ← 지도 이벤트를 MVI Action 으로
        )
        .ignoresSafeArea()
        .navigationTitle("지도")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
