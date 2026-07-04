import FlowCoordination
import MVI
import Observation

/// 지도 flow 안의 라우트. 마커 상세 화면 하나.
public enum MapRoute: Hashable {
    case markerDetail(String)
}

/// 지도 flow 의 루트 Coordinator. 지도 이벤트로 발생한 NavigationEffect 를 push 로 라우팅한다.
/// 종료되지 않는 루트 flow → `FlowFinish<Never>` 로 발사를 컴파일 단계에서 차단.
@Observable
@MainActor
public final class MapCoordinator: Coordinator {
    // MARK: - Capabilities
    public var path: [MapRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    // MARK: - Lifecycle
    // 지도 데이터가 아직 도메인이 아니라 UseCase 가 없다 → deps 를 받지 않는다.
    // 마커가 도메인 데이터가 되면 자기 전용 `MapDeps`(FetchXxxUseCase)를 정의해 주입한다.
    public init() {}

    // MARK: - Store Factory
    public func makeHomeStore() -> MapHomeStore {
        let store = MapHomeStore(MapHomeState.seoulSample(), reduce: mapHomeReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }   // 필수 — 누락 시 navigation 이 조용히 안 됨
        return store
    }

    // MARK: - Navigation Routing (테스트가 직접 호출)
    func handle(_ nav: MapHomeNav) {
        switch nav {
        case .goToMarkerDetail(let id):
            push(.markerDetail(id))
        }
    }
}
