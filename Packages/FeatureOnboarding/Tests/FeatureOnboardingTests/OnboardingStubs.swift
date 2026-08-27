import Core
import Domain
@testable import FeatureOnboarding

/// 온보딩 Coordinator 배선 테스트용 deps. 라우팅만 보는 테스트라 UseCase 는 부르지 않는다.
struct StubOnboardingDeps: OnboardingDeps {
    var registerProfile: RegisterProfileUseCase = StubRegisterProfile()
    var fetchInviteCode: FetchInviteCodeUseCase = StubFetchInviteCode()
    var deeplink = DeeplinkConfiguration(scheme: "gguk", host: "gguk.org")
}

private struct StubRegisterProfile: RegisterProfileUseCase {
    func execute(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        Profile(id: "user-1", nickname: nickname, avatarColor: avatarColor, createdAt: nil)
    }
}

private struct StubFetchInviteCode: FetchInviteCodeUseCase {
    func execute(roomId: String) async throws -> String { "K7Q2MZ" }
}
