import Domain

/// OnboardingCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수한다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
public protocol OnboardingDeps: Sendable {
    var createRoom: CreateRoomUseCase { get }
}
