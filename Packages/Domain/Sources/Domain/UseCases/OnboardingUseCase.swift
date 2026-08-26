import Foundation

/// 온보딩은 최초 1회만 거친다 — 그 완료 여부를 판단·기록한다.
///
/// **기록이 남지 않으면 앱을 껐다 켤 때마다 온보딩이 다시 뜬다.** 실제로 그렇게 깨진 적이 있어
/// (앱 진입 온보딩 연결이 되돌려진 이력) 완료 표시를 영속화하는 것이 이 UseCase 의 존재 이유다.
public protocol OnboardingUseCase: Sendable {
    /// 이미 마쳤으면 true (= 다시 띄우지 않는다).
    func hasCompleted() async -> Bool
    func markCompleted() async
}

public struct DefaultOnboardingUseCase: OnboardingUseCase {
    private let repository: OnboardingRepository

    public init(repository: OnboardingRepository) {
        self.repository = repository
    }

    public func hasCompleted() async -> Bool {
        await repository.hasCompletedOnboarding()
    }

    public func markCompleted() async {
        await repository.markOnboardingCompleted()
    }
}
