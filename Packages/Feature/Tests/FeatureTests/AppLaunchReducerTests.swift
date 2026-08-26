import Testing
import Domain
import MVITestSupport
@testable import Feature

private struct StubEnsureSession: EnsureSessionUseCase {
    var result: Result<UserSession, DomainError> = .success(UserSession(userID: "uid-1"))
    func execute() async throws -> UserSession {
        switch result {
        case .success(let session): return session
        case .failure(let error): throw error
        }
    }
}

/// 완료 표시가 실제로 기록되는지 세어 본다 — 기록 누락이 온보딩 재노출의 원인이었다.
private actor SpyOnboarding: OnboardingUseCase {
    private var completed: Bool
    private(set) var markCalls = 0

    init(completed: Bool) { self.completed = completed }

    func hasCompleted() async -> Bool { completed }

    func markCompleted() async {
        markCalls += 1
        completed = true
    }
}

@MainActor
struct AppLaunchReducerTests {
    private func makeStore(
        ensureSession: EnsureSessionUseCase = StubEnsureSession(),
        onboarding: OnboardingUseCase = SpyOnboarding(completed: true),
        state: AppLaunchState = AppLaunchState()
    ) -> TestStore<AppLaunchState, AppLaunchAction, Never> {
        TestStore(state, reduce: appLaunchReducer(ensureSession: ensureSession, onboarding: onboarding))
    }

    @Test("L2 — 세션을 얻고 온보딩을 마쳤으면 메인으로 간다")
    func start_completedOnboarding_goesToMain() async {
        let store = makeStore(onboarding: SpyOnboarding(completed: true))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }

        store.finish()
    }

    @Test("L2 — 세션을 얻었지만 온보딩 전이면 온보딩으로 간다")
    func start_pendingOnboarding_goesToOnboarding() async {
        let store = makeStore(onboarding: SpyOnboarding(completed: false))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: true)) { $0.phase = .onboarding }

        store.finish()
    }

    // 세션 없이 들여보내면 모든 API 가 401 이라 화면마다 오류만 뜬다. 진입 자체를 막는다.
    @Test("L2 — 세션 확보에 실패하면 재시도 화면에 머문다")
    func start_failure_showsRetry() async {
        let store = makeStore(ensureSession: StubEnsureSession(result: .failure(.sessionUnavailable)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed) { $0.phase = .retry }

        store.finish()
    }

    @Test("L2 — 재시도가 성공하면 진입이 뚫린다")
    func tapRetry_success_recovers() async {
        let store = makeStore(state: AppLaunchState(phase: .retry))

        await store.send(.tapRetry) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }

        store.finish()
    }

    // SwiftUI .task 가 두 번 돌아도 세션 확보가 겹쳐 발사되면 안 된다.
    @Test("L1 — 두 번째 start 는 무시된다")
    func start_isIdempotent() async {
        let store = makeStore()

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }
        await store.send(.start)   // 상태 변화도, effect 도 없다

        store.finish()
    }

    @Test("L1 — 로딩 중 재시도 연타는 무시된다")
    func tapRetry_ignoredWhileLoading() async {
        let store = makeStore(state: AppLaunchState(phase: .loading))

        await store.send(.tapRetry)   // 세션 확보를 겹쳐 발사하지 않는다

        store.finish()
    }

    @Test("L2 — 온보딩을 마치면 메인으로 가고 완료를 기록한다")
    func onboardingFinished_marksCompleted() async {
        let spy = SpyOnboarding(completed: false)
        let store = makeStore(onboarding: spy, state: AppLaunchState(phase: .onboarding))

        await store.send(.onboardingFinished) { $0.phase = .main }

        #expect(await spy.markCalls == 1)
        store.finish()
    }

    // 기록이 남지 않으면 다음 실행에 온보딩이 다시 뜬다 — 되돌려진 적이 있는 실패다.
    @Test("L2 — 온보딩을 마친 뒤 다시 진입하면 곧장 메인이다")
    func afterOnboarding_nextLaunchSkipsIt() async {
        let spy = SpyOnboarding(completed: false)

        let first = makeStore(onboarding: spy, state: AppLaunchState(phase: .onboarding))
        await first.send(.onboardingFinished) { $0.phase = .main }
        first.finish()

        let second = makeStore(onboarding: spy)
        await second.send(.start) { $0.phase = .loading }
        await second.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }
        second.finish()
    }
}
