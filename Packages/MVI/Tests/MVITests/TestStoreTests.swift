import Testing
import MVI
import MVITestSupport

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

    // MARK: - 음성 케이스 (TestStore 가 실제로 회귀를 잡는지 검증)

    @Test("틀린 state 단언은 실패로 잡힌다")
    func wrong_state_assertion_is_caught() async {
        await withKnownIssue {
            let store = TestStore(CounterState(), reduce: counterReducer)
            await store.send(.increment) { $0.count = 99 }   // 실제 1 인데 99 기대
        }
    }

    @Test("미수신 effect action 은 finish 에서 실패로 잡힌다")
    func unhandled_effect_is_caught() async {
        await withKnownIssue {
            let store = TestStore(CounterState(), reduce: counterReducer)
            await store.send(.load) { $0.isLoading = true }
            store.finish()   // .loaded 를 receive 하지 않음 → 미처리 pending
        }
    }

    @Test("보낸 적 없는 effect action 을 receive 하면 실패로 잡힌다")
    func receive_missing_action_is_caught() async {
        await withKnownIssue {
            let store = TestStore(CounterState(), reduce: counterReducer)
            await store.receive(.loaded(10))   // 발사된 적 없음
        }
    }

    // MARK: - 비-exhaustive 모드 (중간 단언 생략, 최종만 직접 확인)

    @Test("exhaustive=false 면 중간 단언을 건너뛰고 최종만 확인한다")
    func non_exhaustive_final_only() async {
        let store = TestStore(CounterState(), reduce: counterReducer)
        store.exhaustive = false
        await store.send(.load)                   // isLoading 안 적어도 통과
        await store.receive(.loaded(10))          // 중간 state 단언 생략
        store.receiveNavigation(.finished)
        store.finish()                            // 잔여 검사도 꺼짐
        #expect(store.currentState.count == 10)   // 최종만 직접 확인
    }
}
