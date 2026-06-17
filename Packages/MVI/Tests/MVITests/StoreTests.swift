import Testing
import MVI

/// AsyncStream 에서 첫 요소를 받되, 회귀로 yield 가 안 오면 무한 hang 대신 타임아웃으로 nil 을 돌려준다.
/// (회귀를 '멈춤'이 아니라 '실패'로 표면화하기 위함)
func firstValue<T: Sendable>(
    from stream: AsyncStream<T>,
    timeout: Duration = .seconds(2)
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { for await value in stream { return value }; return nil }
        group.addTask { try? await Task.sleep(for: timeout); return nil }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}

/// production `Store` 의 실행 엔진(AsyncStream yield, run effect Task) 검증.
/// TestStore.drain 과 별개 구현이므로 직접 테스트한다.
@MainActor
struct StoreTests {
    @Test("navigate effect 가 navigationEffects 스트림으로 yield 된다")
    func navigate_yields_to_stream() async {
        let store = Store(CounterState(), reduce: counterReducer)
        store.send(.load)   // load → run → loaded → navigate(.finished)

        let received = await firstValue(from: store.navigationEffects)   // 회귀 시 hang 대신 타임아웃
        #expect(received == .finished)
    }

    @Test("run effect 가 Task 로 실행되어 Response Action 이 state 에 반영된다")
    func run_effect_updates_state() async {
        let store = Store(CounterState(), reduce: counterReducer)
        store.send(.load)

        for _ in 0..<100 where store.state.count != 10 {
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
