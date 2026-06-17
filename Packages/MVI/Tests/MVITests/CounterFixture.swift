import MVI

// TestStore / Store 테스트가 공유하는 검증용 샘플 도메인.
struct CounterState: Equatable {
    var count = 0
    var isLoading = false
    var error: String?
}

enum CounterAction: Equatable {
    case increment
    case load
    case loaded(Int)
    case loadFailing            // 실패하는 비동기 로드
    case loadFailed(String)     // 실패 Response Action
}

enum CounterNav: Equatable, Sendable {
    case finished
}

func counterReducer(
    _ state: inout CounterState,
    _ action: CounterAction
) -> Effect<CounterAction, CounterNav> {
    switch action {
    case .increment:
        state.count += 1
        return .none
    case .load:
        state.isLoading = true
        state.error = nil
        return .run { send in send(.loaded(10)) }
    case .loaded(let value):
        state.count = value
        state.isLoading = false
        return .navigate(.finished)
    case .loadFailing:
        state.isLoading = true
        state.error = nil
        return .run { send in send(.loadFailed("실패")) }
    case .loadFailed(let message):
        state.isLoading = false
        state.error = message
        return .none
    }
}
