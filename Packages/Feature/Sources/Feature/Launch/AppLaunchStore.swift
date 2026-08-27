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
    fetchProfile: FetchProfileUseCase
) -> (inout AppLaunchState, AppLaunchAction) -> Effect<AppLaunchAction, Never> {
    { state, action in
        switch action {
        case .start:
            guard state.phase == .idle else { return .none }
            state.phase = .loading
            return establishSession(ensureSession, fetchProfile)

        // 재시도 화면에서만 유효하다. 로딩 중 연타가 세션 확보를 겹쳐 발사하지 않게 막는다.
        case .tapRetry:
            guard state.phase == .retry else { return .none }
            state.phase = .loading
            return establishSession(ensureSession, fetchProfile)

        case .sessionReady(let needsOnboarding):
            state.phase = needsOnboarding ? .onboarding : .main
            return .none

        // 세션 없이 들여보내도 모든 API 가 401 이라 할 수 있는 게 없다. 진입을 막고 재시도를 준다.
        case .sessionFailed:
            state.phase = .retry
            return .none

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
/// 대가는 앱 시작마다 네트워크 1회다. 실패는 이미 있는 재시도 화면이 받는다.
private func establishSession(
    _ ensureSession: EnsureSessionUseCase,
    _ fetchProfile: FetchProfileUseCase
) -> Effect<AppLaunchAction, Never> {
    .run { send in
        do {
            _ = try await ensureSession.execute()
            _ = try await fetchProfile.execute()
            send(.sessionReady(needsOnboarding: false))
        // 미등록은 인증 실패가 아니다 — 온보딩을 마치면 풀린다. 재시도 화면으로 보내면
        // 최초 사용자가 "다시 시도" 만 반복하며 앱에 들어오지 못한다.
        } catch DomainError.notRegistered {
            send(.sessionReady(needsOnboarding: true))
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
