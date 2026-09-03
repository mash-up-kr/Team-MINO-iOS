import Domain
import MVI

/// 스플래시가 세션을 기다리는 동안 쓰는 시간 값. 시안 012-2 의 "3초"·"10초"가 여기 모여 있다.
public struct AppLaunchTiming: Equatable, Sendable {
    /// 이 시간이 지나도 세션이 안 오면 로딩 스피너를 켠다.
    public let slowAfter: Duration
    /// 시도 시작 후 이 시간이 지나면 스피너를 끄고 일시적 오류를 안내한다.
    /// **요청을 끊지는 않는다** — 늦게라도 오면 그대로 진입한다.
    public let timeoutAfter: Duration
    /// 실패 후 자동 재시도까지의 대기. 시도마다 두 배로 늘리고 `maxRetryBackoff` 에서 멈춘다.
    public let retryBackoff: Duration
    public let maxRetryBackoff: Duration

    public init(
        slowAfter: Duration = .seconds(3),
        timeoutAfter: Duration = .seconds(10),
        retryBackoff: Duration = .seconds(3),
        maxRetryBackoff: Duration = .seconds(30)
    ) {
        self.slowAfter = slowAfter
        self.timeoutAfter = timeoutAfter
        self.retryBackoff = retryBackoff
        self.maxRetryBackoff = maxRetryBackoff
    }

    public static let `default` = AppLaunchTiming()

    /// 실패가 이어질수록 간격을 벌린다 — 연결이 끊긴 채로 초당 한 번씩 두드리지 않기 위해서다.
    func backoff(forRetry count: Int) -> Duration {
        guard count > 1 else { return retryBackoff }
        // 2^30 을 넘어가면 곱셈이 넘치므로 상한에 닿는 즉시 멈춘다.
        var wait = retryBackoff
        for _ in 1..<count {
            if wait >= maxRetryBackoff { return maxRetryBackoff }
            wait = wait * 2
        }
        return min(wait, maxRetryBackoff)
    }
}

/// 앱 진입 화면의 상태. 어느 화면을 띄울지가 `phase` 하나로 정해지고,
/// 스플래시에 얹는 장식(스피너·스낵바)은 나머지 필드가 정한다.
public struct AppLaunchState: Equatable {
    public enum Phase: Equatable {
        /// 아직 시작 전. `.start` 는 이 상태에서만 유효하다 — SwiftUI `.task` 의 실행 횟수에
        /// 기대지 않고 reduce 가 직접 막아 테스트로 고정한다.
        case idle
        /// 세션을 확보하는 중. 런치스크린과 이어지는 구간이다.
        /// **실패해도 여기 머문다** — 자동 재시도가 도는 동안 스낵바만 얹힌다.
        case loading
        case onboarding
        case main
    }

    /// 스플래시 하단에 띄우는 스낵바. 시안 012-3 / 012-4.
    public enum Notice: Equatable {
        /// 기기가 네트워크에 닿지 못했다.
        case networkError
        /// 그 밖의 실패, 그리고 응답이 너무 늦을 때.
        case temporaryError
    }

    public var phase: Phase
    /// 세션이 늦어질 때만 켠다(시안 012-2). 타임아웃·실패 뒤에는 끈다.
    public var isSlow: Bool
    /// nil 이면 스낵바를 띄우지 않는다.
    public var notice: Notice?
    /// 자동 재시도가 몇 번째인지. 백오프 계산에만 쓴다.
    public var retryCount: Int

    public init(phase: Phase = .idle, isSlow: Bool = false, notice: Notice? = nil, retryCount: Int = 0) {
        self.phase = phase
        self.isSlow = isSlow
        self.notice = notice
        self.retryCount = retryCount
    }
}

public enum AppLaunchAction: Equatable {
    case start
    case attemptIsSlow                          // slowAfter 경과, 아직 결과 없음
    case attemptTimedOut                        // timeoutAfter 경과, 아직 결과 없음
    case sessionReady(needsOnboarding: Bool)    // Response Action (성공)
    case sessionFailed(AppLaunchState.Notice)   // Response Action (실패)
    case retryNow                               // 백오프 뒤 자동 재시도
    case onboardingFinished
}

/// 화면 전환이 `phase` 로 표현되므로 이 flow 에는 navigation 채널이 없다.
/// `Never` 로 두면 `.navigate` 를 만드는 것 자체가 컴파일 단계에서 막힌다.
public typealias AppLaunchStore = Store<AppLaunchState, AppLaunchAction, Never>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 쓴다.
public func appLaunchReducer(
    ensureSession: EnsureSessionUseCase,
    fetchProfile: FetchProfileUseCase,
    timing: AppLaunchTiming = .default
) -> (inout AppLaunchState, AppLaunchAction) -> Effect<AppLaunchAction, Never> {
    { state, action in
        switch action {
        case .start:
            guard state.phase == .idle else { return .none }
            state.phase = .loading
            return establishSession(ensureSession, fetchProfile, timing)

        case .attemptIsSlow:
            guard state.phase == .loading else { return .none }
            state.isSlow = true
            return .none

        // 스피너를 내리고 안내로 바꾼다. 요청은 살아 있어 성공하면 그대로 진입한다.
        case .attemptTimedOut:
            guard state.phase == .loading else { return .none }
            state.isSlow = false
            state.notice = .temporaryError
            return .none

        case .sessionReady(let needsOnboarding):
            state.isSlow = false
            state.notice = nil
            state.retryCount = 0
            state.phase = needsOnboarding ? .onboarding : .main
            return .none

        // 세션 없이 들여보내도 모든 API 가 401 이라 할 수 있는 게 없다. 진입을 막고,
        // 시안에 재시도 버튼이 없으므로 **사용자 조작 없이 스스로 다시 시도한다**.
        case .sessionFailed(let notice):
            guard state.phase == .loading else { return .none }
            state.isSlow = false
            state.notice = notice
            state.retryCount += 1
            let wait = timing.backoff(forRetry: state.retryCount)
            return .run { send in
                try? await Task.sleep(for: wait)
                guard !Task.isCancelled else { return }
                send(.retryNow)
            }

        case .retryNow:
            guard state.phase == .loading else { return .none }
            state.notice = nil                  // 다시 시도하는 동안은 안내를 지운다
            return establishSession(ensureSession, fetchProfile, timing)

        // 기록할 것이 없다. 온보딩을 마쳤다는 사실은 **서버에 회원이 생긴 것** 그 자체이고,
        // 다음 실행은 그걸 `GET /me` 로 다시 확인한다.
        case .onboardingFinished:
            state.phase = .main
            return .none
        }
    }
}

/// 세션 확보와 등록 여부 확인을 **한 effect 로 묶는다.** 두 결과가 합쳐져야 갈 화면이 정해지는데,
/// 나눠 보내면 그 사이에 화면이 그릴 수 없는 중간 상태(세션은 됐고 등록 여부는 모름)가 생긴다.
///
/// **판단을 서버에 묻는다.** 로컬 플래그로는 네 경우 중 둘이 틀린다 — 재설치하면 익명 세션은
/// Keychain 에 남아 돌아오는데 플래그만 사라져 등록된 사용자가 온보딩에 갇히고, 반대로
/// "세션이 있으면 완료"로 보면 온보딩 중간에 종료한 사용자가 프로필 없이 메인으로 들어간다
/// (세션은 온보딩 화면이 뜨기 **전에** 만들어진다). 어느 쪽도 로컬에서는 알 수 없다.
///
/// 대가는 앱 시작마다 네트워크 1회다. 실패는 스낵바와 자동 재시도가 받는다.
private func establishSession(
    _ ensureSession: EnsureSessionUseCase,
    _ fetchProfile: FetchProfileUseCase,
    _ timing: AppLaunchTiming
) -> Effect<AppLaunchAction, Never> {
    .run { send in
        // 지연 안내(스피너 → 타임아웃)는 이 시도와 수명이 같다. 같은 effect 안에 두어야
        // 요청이 끝날 때 함께 접히고, 지나간 시도의 안내가 뒤늦게 뜨지 않는다.
        let notices = Task { @MainActor in
            try? await Task.sleep(for: timing.slowAfter)
            guard !Task.isCancelled else { return }
            send(.attemptIsSlow)
            try? await Task.sleep(for: max(.zero, timing.timeoutAfter - timing.slowAfter))
            guard !Task.isCancelled else { return }
            send(.attemptTimedOut)
        }
        defer { notices.cancel() }

        do {
            _ = try await ensureSession.execute()
            _ = try await fetchProfile.execute()
            send(.sessionReady(needsOnboarding: false))
        // 미등록은 인증 실패가 아니다 — 온보딩을 마치면 풀린다. 실패로 보내면
        // 최초 사용자가 재시도만 반복하며 앱에 들어오지 못한다.
        } catch DomainError.notRegistered {
            send(.sessionReady(needsOnboarding: true))
        // 취소는 실패가 아니다. 흡수하면 이미 화면을 벗어난 뒤에 스낵바가 뜬다.
        // (이 Store 는 앱 수명이라 실제 취소 경로가 지금은 없지만, 화면 reducer 가 이 파일을 본보기로 삼는다)
        } catch is CancellationError {
            return
        // 연결 문제만 갈라 "연결을 확인해주세요"로 안내한다. 나머지는 사용자가 손댈 게 없어
        // 원인을 밝히지 않고 "일시적인 오류"로 뭉갠다.
        } catch DomainError.networkUnavailable {
            send(.sessionFailed(.networkError))
        } catch {
            send(.sessionFailed(.temporaryError))
        }
    }
}
