import Testing
import Domain
import MVITestSupport
@testable import Feature

private struct CancellingEnsureSession: EnsureSessionUseCase {
    func execute() async throws -> UserSession { throw CancellationError() }
}

private struct StubEnsureSession: EnsureSessionUseCase {
    var result: Result<UserSession, DomainError> = .success(UserSession(userID: "uid-1"))
    func execute() async throws -> UserSession {
        switch result {
        case .success(let session): return session
        case .failure(let error): throw error
        }
    }
}

/// 등록 여부를 서버에 묻는 창구. 조회가 성공하면 등록된 것이고, `.notRegistered` 면 온보딩 전이다.
private struct StubFetchProfile: FetchProfileUseCase {
    var result: Result<Profile, DomainError> = .success(Profile(id: "user-1", nickname: "꾹이", avatarIndex: 0, createdAt: nil))

    func execute() async throws -> Profile {
        try result.get()
    }
}

@MainActor
struct AppLaunchReducerTests {
    private func makeStore(
        ensureSession: EnsureSessionUseCase = StubEnsureSession(),
        fetchProfile: FetchProfileUseCase = StubFetchProfile(),
        state: AppLaunchState = AppLaunchState()
    ) -> TestStore<AppLaunchState, AppLaunchAction, Never> {
        TestStore(state, reduce: appLaunchReducer(ensureSession: ensureSession, fetchProfile: fetchProfile))
    }

    /// 미등록(서버 401 + USER_NOT_REGISTERED)을 흉내 내는 조회.
    private static let unregistered = StubFetchProfile(result: .failure(.notRegistered))

    @Test("L2 — 프로필이 있으면(등록됨) 메인으로 간다")
    func start_registered_goesToMain() async {
        let store = makeStore()

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }

        store.finish()
    }

    // 미등록은 401 로 오지만 인증 실패가 아니다 — 재시도가 아니라 온보딩으로 보내야 한다.
    @Test("L2 — 세션은 있으나 미등록이면 온보딩으로 간다")
    func start_notRegistered_goesToOnboarding() async {
        let store = makeStore(fetchProfile: Self.unregistered)

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

    // 취소를 실패로 흡수하면 이미 화면을 벗어난 뒤에 재시도 화면이 뜬다 —
    // 사용자에겐 오지 않은 오류가 된다.
    @Test("L2 — 취소는 실패로 뒤집히지 않는다")
    func cancellation_doesNotBecomeFailure() async {
        let store = makeStore(ensureSession: CancellingEnsureSession())

        await store.send(.start) { $0.phase = .loading }   // 이후 아무 action 도 오지 않는다

        store.finish()
    }

    // 인증 실패는 온보딩으로 보내지 않는다 — 프로필을 만들어도 토큰이 그대로라 등록이 다시 막힌다.
    @Test("L2 — 401 이어도 미등록이 아니면 재시도 화면이다")
    func start_unauthorized_showsRetry() async {
        let store = makeStore(fetchProfile: StubFetchProfile(result: .failure(.unauthorized)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed) { $0.phase = .retry }

        store.finish()
    }

    // 조회 자체가 실패한 것(네트워크 등)은 등록 여부를 **모르는** 상태다. 모른 채 메인으로
    // 들여보내면 등록 전 사용자가 프로필 없이 들어가고, 온보딩으로 보내면 등록된 사용자가 다시 탄다.
    @Test("L2 — 프로필 조회가 실패하면 재시도 화면이다")
    func start_profileFetchFailure_showsRetry() async {
        let store = makeStore(fetchProfile: StubFetchProfile(result: .failure(.profileFetchFailed)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed) { $0.phase = .retry }

        store.finish()
    }

    // 완료를 로컬에 기록하지 않는다 — 서버에 회원이 생긴 것이 곧 기록이다.
    @Test("L2 — 온보딩을 마치면 메인으로 가고 남기는 부수효과가 없다")
    func onboardingFinished_goesToMainWithoutSideEffect() async {
        let store = makeStore(state: AppLaunchState(phase: .onboarding))

        await store.send(.onboardingFinished) { $0.phase = .main }

        store.finish()   // 미처리 effect 가 있으면 여기서 실패한다
    }

    // 재설치 재현: 익명 세션은 Keychain 에 남아 같은 uid 로 돌아오고 로컬 플래그만 사라진다.
    // 판단을 서버에 물으므로 이 경우가 메인으로 간다(전에는 온보딩에 갇혔다).
    @Test("L2 — 재설치해도 서버에 회원이 있으면 곧장 메인이다")
    func reinstall_withServerAccount_goesToMain() async {
        let store = makeStore()   // 로컬엔 아무 기록도 없다

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }

        store.finish()
    }
}
