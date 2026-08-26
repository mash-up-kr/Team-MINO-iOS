import MVI

// [Convention] .claude/docs/mvi-coordinator-di-extensions.md 「makeStore 공통화」 — 두 번째
// Coordinator(HomeCoordinator) 이후 "사례 2개를 보고 결정"하기로 미뤄뒀던 추출을 세 번째
// Coordinator(NotificationCoordinator) 시점에 한다.
// FlowCoordination 이 MVI 를 의존하게 되는 것도 그 문서가 이미 예견한 파생 변경이다
// ("모듈 의존을 엮어야 해 사례 2개를 보고 결정").

public extension Coordinator {
    /// `Store` 생성 + `observeNavigation` 구독을 한 번에 한다. 각 Coordinator 의 `make<화면>Store()`
    /// 팩토리가 반복하던 두 줄("Store(...) + observeNavigation { ... }")을 여기로 모은다.
    ///
    /// `observeNavigation` 을 빠뜨리면 navigation 이 크래시·로그 없이 안 되는데(`mvi-coordinator-di.md`
    /// §4), 이 헬퍼를 쓰면 그 누락이 구조적으로 불가능해진다.
    @MainActor
    func makeStore<State, Action, Nav: Sendable>(
        _ initial: State,
        reduce: @escaping (inout State, Action) -> Effect<Action, Nav>,
        handle: @escaping @MainActor (Nav) -> Void
    ) -> Store<State, Action, Nav> {
        let store = Store(initial, reduce: reduce)
        store.observeNavigation(handle)
        return store
    }
}
