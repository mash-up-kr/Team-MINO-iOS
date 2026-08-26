import Domain
@testable import FeatureOnboarding

/// 온보딩 Coordinator 배선 테스트용 deps. 라우팅만 보는 테스트라 UseCase 는 부르지 않는다.
struct StubOnboardingDeps: OnboardingDeps {
    var registerProfile: RegisterProfileUseCase = StubRegisterProfile()
}

private struct StubRegisterProfile: RegisterProfileUseCase {
    func execute(nickname: String, avatarIndex: Int) async throws -> Profile {
        Profile(id: "user-1", nickname: nickname, avatarIndex: avatarIndex, createdAt: nil)
    }
}
