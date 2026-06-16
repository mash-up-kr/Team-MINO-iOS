import Testing
import MVI
import MVITestSupport

// 검증용 샘플 reducer
private struct CounterState: Equatable {
    var count = 0
    var isLoading = false
}

private enum CounterAction: Equatable {
    case increment
    case load
    case loaded(Int)
}

private enum CounterNav: Equatable {
    case finished
}

private func counterReducer(
    _ state: inout CounterState,
    _ action: CounterAction
) -> Effect<CounterAction, CounterNav> {
    switch action {
    case .increment:
        state.count += 1
        return .none
    case .load:
        state.isLoading = true
        return .run { send in send(.loaded(10)) }
    case .loaded(let value):
        state.count = value
        state.isLoading = false
        return .navigate(.finished)
    }
}

@MainActor
struct TestStoreTests {
    @Test("L1 — 동기 action 의 상태 전이를 단언한다")
    func sync_transition() async {
        let store = TestStore(CounterState(), reduce: counterReducer)
        await store.send(.increment) { $0.count = 1 }
        store.finish()
    }

    @Test("L2 — run effect 가 보낸 Response Action 까지 시나리오를 검증한다")
    func async_scenario() async {
        let store = TestStore(CounterState(), reduce: counterReducer)
        await store.send(.load) { $0.isLoading = true }
        await store.receive(.loaded(10)) {
            $0.count = 10
            $0.isLoading = false
        }
        store.receiveNavigation(.finished)
        store.finish()
    }

    @Test("navigate effect 가 nav 채널로 수집된다")
    func navigation_collected() async {
        let store = TestStore(CounterState(), reduce: counterReducer)
        await store.send(.load) { $0.isLoading = true }
        await store.receive(.loaded(10)) {
            $0.count = 10
            $0.isLoading = false
        }
        store.receiveNavigation(.finished)
        store.finish()
    }
}
