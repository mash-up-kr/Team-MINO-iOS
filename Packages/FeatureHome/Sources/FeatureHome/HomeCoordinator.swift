import Domain
import FlowCoordination
import MVI
import SwiftUI

/// 홈 탭 flow. 방 생성 등 하위 화면이 추가되면 Route 를 확장한다.
public enum HomeRoute: Hashable {}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class HomeCoordinator: Coordinator {
    public var path: [HomeRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    private let deps: HomeDeps

    public init(deps: HomeDeps) {
        self.deps = deps
    }

    // MARK: - Store Factory

    public func makeHomeStore() -> HomeStore {
        let store = HomeStore(
            HomeState(),
            reduce: homeReducer(fetchRooms: deps.fetchRooms)
        )
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    // MARK: - Navigation Routing

    func handle(_ nav: HomeNav) {
        switch nav {
        case .goToCreateRoom:
            // PR4에서 방 생성 화면 push 구현
            break
        }
    }
}
