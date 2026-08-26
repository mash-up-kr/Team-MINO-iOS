import Testing
import Observation
import MVI
@testable import FlowCoordination

@MainActor
struct CoordinatorMakeStoreTests {
    @Test("Store 를 만들고 observeNavigation 을 구독한다")
    func makesStoreAndSubscribesNavigation() async throws {
        let coordinator = DummyCoordinator()
        var receivedNav: DummyNav?

        let store = coordinator.makeStore(
            0,
            reduce: { (state: inout Int, action: DummyAction) -> Effect<DummyAction, DummyNav> in
                switch action {
                case .increment: state += 1; return .none
                case .finish: return .navigate(.done)
                }
            },
            handle: { receivedNav = $0 }
        )

        store.send(.increment)
        #expect(store.state == 1)

        store.send(.finish)
        // navigate 는 AsyncStream 을 거쳐 비동기로 전달된다 — 구독 Task 가 처리할 때까지 폴링(유한 종료, StoreTests 패턴과 동일).
        for _ in 0..<1000 where receivedNav == nil {
            await Task.yield()
        }
        #expect(receivedNav == .done)
    }
}

private enum DummyAction: Equatable, Sendable { case increment, finish }
private enum DummyNav: Equatable, Sendable { case done }

@Observable
@MainActor
private final class DummyCoordinator: Coordinator {
    var path: [Never] = []
    var sheet: Never?
    var cover: Never?
    let finish = FlowFinish<Never>()
}
