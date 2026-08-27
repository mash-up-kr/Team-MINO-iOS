import Foundation

/// 온보딩을 이미 마쳤는지 기억하는 저장소 추상.
/// 저장 매체(UserDefaults·서버)가 무엇인지 Domain 은 알지 못한다.
public protocol OnboardingRepository: Sendable {
    func hasCompletedOnboarding() async -> Bool
    func markOnboardingCompleted() async
}
