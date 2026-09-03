import Testing
import MVI

/// production `Store` 의 실행 엔진(navigation 전달, run effect Task) 검증.
/// TestStore.drain 과 별개 구현이므로 직접 테스트한다.
@MainActor
struct StoreTests {
    @Test("navigate effect 가 observeNavigation 으로 전달된다")
    func navigate_delivered_to_observer() async {
        let store = Store(CounterState(), reduce: counterReducer)
        var received: CounterNav?
        store.observeNavigation { received = $0 }

        store.send(.load)   // load → run → loaded → navigate(.finished)

        // 구독 Task 가 nav 를 전달할 때까지 대기(폴링이라 회귀 시 hang 없이 유한 종료).
        for _ in 0..<1000 where received == nil {
            await Task.yield()
        }
        #expect(received == .finished)
    }

    @Test("init(_:reduce:handle:) 가 생성과 동시에 navigation 을 구독한다")
    func convenienceInit_subscribes_navigation() async {
        var received: CounterNav?
        // observeNavigation 을 따로 부르지 않는다 — init 이 대신 구독한 것이 검증 대상이다.
        let store = Store(CounterState(), reduce: counterReducer, handle: { received = $0 })

        store.send(.load)   // load → run → loaded → navigate(.finished)

        for _ in 0..<1000 where received == nil {
            await Task.yield()
        }
        #expect(received == .finished)
    }

    @Test("run effect 가 Task 로 실행되어 Response Action 이 state 에 반영된다")
    func run_effect_updates_state() async {
        let store = Store(CounterState(), reduce: counterReducer)
        store.send(.load)

        for _ in 0..<1000 where store.state.count != 10 {
            await Task.yield()
        }
        #expect(store.state.count == 10)
        #expect(store.state.isLoading == false)
    }

    @Test("none effect 는 동기 상태 전이만 일으킨다")
    func none_effect_sync_only() {
        let store = Store(CounterState(), reduce: counterReducer)
        store.send(.increment)
        #expect(store.state.count == 1)
    }
}
