import Domain
import MVI

/// 앱 진입 화면의 상태. 어느 화면을 띄울지가 `phase` 하나로 정해진다.
public struct AppLaunchState: Equatable {
    public enum Phase: Equatable {
        /// 아직 시작 전. `.start` 는 이 상태에서만 유효하다 — SwiftUI `.task` 의 실행 횟수에
        /// 기대지 않고 reduce 가 직접 막아 테스트로 고정한다.
        case idle
        /// 세션을 확보하는 중. 런치스크린과 이어지는 구간이다.
        case loading
        /// 세션을 못 얻었다(네트워크 단절 등). 사용자가 다시 시도할 수 있다.
        case retry
        case onboarding
        case main
    }

    public var phase: Phase

    public init(phase: Phase = .idle) {
        self.phase = phase
    }
}

public enum AppLaunchAction: Equatable {
    case start
    case sessionReady(needsOnboarding: Bool)   // Response Action (성공)
    case sessionFailed                         // Response Action (실패)
    case tapRetry
    case onboardingFinished
}

/// 화면 전환이 `phase` 로 표현되므로 이 flow 에는 navigation 채널이 없다.
/// `Never` 로 두면 `.navigate` 를 만드는 것 자체가 컴파일 단계에서 막힌다.
public typealias AppLaunchStore = Store<AppLaunchState, AppLaunchAction, Never>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 쓴다.
public func appLaunchReducer(
    ensureSession: EnsureSessionUseCase,
    onboarding: OnboardingUseCase
) -> (inout AppLaunchState, AppLaunchAction) -> Effect<AppLaunchAction, Never> {
    { state, action in
        switch action {
        case .start:
            guard state.phase == .idle else { return .none }
            state.phase = .loading
            return establishSession(ensureSession, onboarding)

        // 재시도 화면에서만 유효하다. 로딩 중 연타가 세션 확보를 겹쳐 발사하지 않게 막는다.
        case .tapRetry:
            guard state.phase == .retry else { return .none }
            state.phase = .loading
            return establishSession(ensureSession, onboarding)

        case .sessionReady(let needsOnboarding):
            state.phase = needsOnboarding ? .onboarding : .main
            return .none

        // 세션 없이 들여보내도 모든 API 가 401 이라 할 수 있는 게 없다. 진입을 막고 재시도를 준다.
        case .sessionFailed:
            state.phase = .retry
            return .none

        // 완료를 **여기서 영속화한다.** 기록하지 않으면 다음 실행에 온보딩이 다시 뜬다 —
        // 실제로 그렇게 깨져서 앱 진입 온보딩 연결이 한 번 되돌려진 적이 있다.
        case .onboardingFinished:
            state.phase = .main
            return .run { _ in await onboarding.markCompleted() }
        }
    }
}

/// 세션 확보와 온보딩 조회를 **한 effect 로 묶는다.** 두 결과가 합쳐져야 갈 화면이 정해지는데,
/// 나눠 보내면 그 사이에 화면이 그릴 수 없는 중간 상태(세션은 됐고 온보딩은 모름)가 생긴다.
private func establishSession(
    _ ensureSession: EnsureSessionUseCase,
    _ onboarding: OnboardingUseCase
) -> Effect<AppLaunchAction, Never> {
    .run { send in
        do {
            _ = try await ensureSession.execute()
            let completed = await onboarding.hasCompleted()
            send(.sessionReady(needsOnboarding: !completed))
        // 취소는 실패가 아니다. 흡수하면 재시도 화면이 뜨는데, 이미 화면을 벗어난 뒤라
        // 사용자에겐 오지 않은 오류가 된다. (이 Store 는 앱 수명이라 실제 취소 경로가
        // 지금은 없지만, 화면 reducer 가 이 파일을 본보기로 삼는다)
        } catch is CancellationError {
            return
        } catch {
            send(.sessionFailed)
        }
    }
}
