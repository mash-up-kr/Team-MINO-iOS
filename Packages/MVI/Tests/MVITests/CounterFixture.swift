import MVI

// TestStore / Store 테스트가 공유하는 검증용 샘플 도메인.
struct CounterState: Equatable {
    var count = 0
    var isLoading = false
}

enum CounterAction: Equatable {
    case increment
    case load
    case loaded(Int)
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
        return .run { send in send(.loaded(10)) }
    case .loaded(let value):
        state.count = value
        state.isLoading = false
        return .navigate(.finished)
    }
}
