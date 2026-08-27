import Foundation
import Domain

/// `OnboardingRepository` 의 UserDefaults 구현. 플래그 하나만 남기는 기록이라 별도 저장소를 두지 않는다.
///
/// `@unchecked Sendable`: UserDefaults 는 스레드 안전하다고 문서화돼 있지만 Sendable 로 표시돼 있지 않다.
public struct UserDefaultsOnboardingRepository: OnboardingRepository, @unchecked Sendable {
    private static let key = "onboarding.hasCompleted"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func hasCompletedOnboarding() async -> Bool {
        defaults.bool(forKey: Self.key)
    }

    public func markOnboardingCompleted() async {
        defaults.set(true, forKey: Self.key)
    }
}
