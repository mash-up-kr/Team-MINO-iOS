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

/// 첫 호출만 실패시키는 세션 확보. 자동 재시도가 복구까지 이어지는지 보려면
/// "실패 → 성공"으로 갈리는 창구가 필요하다.
private final class FailingOnceEnsureSession: EnsureSessionUseCase, @unchecked Sendable {
    private var attempts = 0
    private let error: DomainError

    init(error: DomainError) { self.error = error }

    func execute() async throws -> UserSession {
        attempts += 1
        if attempts == 1 { throw error }
        return UserSession(userID: "uid-1")
    }
}

/// 등록 여부를 서버에 묻는 창구. 조회가 성공하면 등록된 것이고, `.notRegistered` 면 온보딩 전이다.
private struct StubFetchProfile: FetchProfileUseCase {
    var result: Result<Profile, DomainError> = .success(Profile(id: "user-1", nickname: "꾹이", avatarColor: .red, createdAt: nil))

    func execute() async throws -> Profile {
        try result.get()
    }
}

@MainActor
struct AppLaunchReducerTests {
    /// 백오프는 0 으로 둔다 — 대기는 `Store` 의 일이고, 여기서 검증할 것은 전이다.
    /// 지연 안내(3초·10초)도 테스트가 action 을 직접 보내 확인하므로 타이머를 태우지 않는다.
    private static let instant = AppLaunchTiming(
        slowAfter: .seconds(60),
        timeoutAfter: .seconds(60),
        retryBackoff: .zero,
        maxRetryBackoff: .zero
    )

    private func makeStore(
        ensureSession: EnsureSessionUseCase = StubEnsureSession(),
        fetchProfile: FetchProfileUseCase = StubFetchProfile(),
        state: AppLaunchState = AppLaunchState()
    ) -> TestStore<AppLaunchState, AppLaunchAction, Never> {
        TestStore(
            state,
            reduce: appLaunchReducer(ensureSession: ensureSession, fetchProfile: fetchProfile, timing: Self.instant)
        )
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

    // MARK: - 지연 안내 (시안 012-2)

    @Test("L1 — 응답이 늦으면 스피너를 켠다")
    func attemptIsSlow_showsSpinner() async {
        let store = makeStore(state: AppLaunchState(phase: .loading))

        await store.send(.attemptIsSlow) { $0.isSlow = true }

        store.finish()
    }

    // 스피너를 계속 돌리면 "곧 될 것"처럼 보인다. 시안은 스피너를 내리고 안내로 바꾼다.
    @Test("L1 — 타임아웃이면 스피너를 내리고 일시적 오류를 안내한다")
    func attemptTimedOut_replacesSpinnerWithNotice() async {
        let store = makeStore(state: AppLaunchState(phase: .loading, isSlow: true))

        await store.send(.attemptTimedOut) {
            $0.isSlow = false
            $0.notice = .temporaryError
        }

        store.finish()
    }

    // 늦게라도 세션이 오면 안내를 걷고 그대로 들어간다 — 타임아웃은 요청을 끊지 않는다.
    @Test("L1 — 타임아웃 뒤에 세션이 와도 진입한다")
    func sessionReady_afterTimeout_clearsNotice() async {
        let store = makeStore(state: AppLaunchState(phase: .loading, notice: .temporaryError))

        await store.send(.sessionReady(needsOnboarding: false)) {
            $0.notice = nil
            $0.phase = .main
        }

        store.finish()
    }

    // MARK: - 실패와 자동 재시도 (시안 012-3 / 012-4)

    // 연결 문제만 "연결을 확인해주세요"로 안내한다 — 나머지는 사용자가 손댈 게 없다.
    @Test("L2 — 네트워크 단절은 네트워크 스낵바로 간다")
    func networkFailure_showsNetworkNotice() async {
        let store = makeStore(ensureSession: StubEnsureSession(result: .failure(.networkUnavailable)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed(.networkError)) {
            $0.notice = .networkError
            $0.retryCount = 1
        }
        await store.receive(.retryNow) { $0.notice = nil }
        await store.receive(.sessionFailed(.networkError)) {   // 여전히 끊겨 있다
            $0.notice = .networkError
            $0.retryCount = 2
        }

        store.exhaustive = false   // 자동 재시도는 끝없이 이어진다 — 두 바퀴로 충분하다
        store.finish()
    }

    @Test("L2 — 그 밖의 실패는 일시적 오류 스낵바로 간다")
    func otherFailure_showsTemporaryNotice() async {
        let store = makeStore(fetchProfile: StubFetchProfile(result: .failure(.profileFetchFailed)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed(.temporaryError)) {
            $0.notice = .temporaryError
            $0.retryCount = 1
        }

        store.exhaustive = false
        store.finish()
    }

    // 인증 실패는 온보딩으로 보내지 않는다 — 프로필을 만들어도 토큰이 그대로라 등록이 다시 막힌다.
    @Test("L2 — 401 이어도 미등록이 아니면 실패로 다룬다")
    func start_unauthorized_isFailure() async {
        let store = makeStore(fetchProfile: StubFetchProfile(result: .failure(.unauthorized)))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed(.temporaryError)) {
            $0.notice = .temporaryError
            $0.retryCount = 1
        }

        store.exhaustive = false
        store.finish()
    }

    // 시안에 재시도 버튼이 없다. 사용자가 아무것도 하지 않아도 복구되어야 한다.
    @Test("L2 — 자동 재시도가 성공하면 사용자 조작 없이 진입한다")
    func autoRetry_recovers() async {
        let store = makeStore(ensureSession: FailingOnceEnsureSession(error: .networkUnavailable))

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionFailed(.networkError)) {
            $0.notice = .networkError
            $0.retryCount = 1
        }
        await store.receive(.retryNow) { $0.notice = nil }
        await store.receive(.sessionReady(needsOnboarding: false)) {
            $0.retryCount = 0
            $0.phase = .main
        }

        store.finish()
    }

    // 실패가 이어질수록 간격을 벌린다 — 끊긴 채로 초당 한 번씩 두드리지 않기 위해서다.
    @Test("L1 — 백오프는 시도마다 두 배로 늘고 상한에서 멈춘다")
    func backoff_doublesUpToCap() {
        let timing = AppLaunchTiming(retryBackoff: .seconds(3), maxRetryBackoff: .seconds(30))

        #expect(timing.backoff(forRetry: 1) == .seconds(3))
        #expect(timing.backoff(forRetry: 2) == .seconds(6))
        #expect(timing.backoff(forRetry: 3) == .seconds(12))
        #expect(timing.backoff(forRetry: 4) == .seconds(24))
        #expect(timing.backoff(forRetry: 5) == .seconds(30))
        #expect(timing.backoff(forRetry: 99) == .seconds(30))
    }

    // MARK: - 가드

    // SwiftUI .task 가 두 번 돌아도 세션 확보가 겹쳐 발사되면 안 된다.
    @Test("L1 — 두 번째 start 는 무시된다")
    func start_isIdempotent() async {
        let store = makeStore()

        await store.send(.start) { $0.phase = .loading }
        await store.receive(.sessionReady(needsOnboarding: false)) { $0.phase = .main }
        await store.send(.start)   // 상태 변화도, effect 도 없다

        store.finish()
    }

    // 진입한 뒤 뒤늦게 도착한 재시도가 사용자를 스플래시로 되돌리면 안 된다.
    @Test("L1 — 진입한 뒤의 재시도는 무시된다")
    func retryNow_ignoredAfterEntering() async {
        let store = makeStore(state: AppLaunchState(phase: .main))

        await store.send(.retryNow)

        store.finish()
    }

    // 취소를 실패로 흡수하면 이미 화면을 벗어난 뒤에 스낵바가 뜬다 — 오지 않은 오류가 된다.
    @Test("L2 — 취소는 실패로 뒤집히지 않는다")
    func cancellation_doesNotBecomeFailure() async {
        let store = makeStore(ensureSession: CancellingEnsureSession())

        await store.send(.start) { $0.phase = .loading }   // 이후 아무 action 도 오지 않는다

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
