import Domain
@testable import FeatureProfile

/// 테스트가 쓰는 기준 프로필. 서버가 주는 모양 그대로다(아바타는 색으로 온다).
extension Profile {
    static func stub(
        nickname: String = "홍길동",
        avatarColor: AvatarColor? = .pink
    ) -> Profile {
        Profile(id: "user-1", nickname: nickname, avatarColor: avatarColor, createdAt: nil)
    }
}

/// 프로필 조회 결과를 정해 주는 스텁.
struct StubFetchProfileUseCase: FetchProfileUseCase {
    var profile: Profile = .stub()
    var error: DomainError?

    func execute() async throws -> Profile {
        if let error { throw error }
        return profile
    }
}

struct StubUpdateProfileUseCase: UpdateProfileUseCase {
    func execute(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        .stub(nickname: nickname ?? "", avatarColor: avatarColor)
    }
}

/// 알림 스위치의 결과를 정해 주는 스텁. 끄기 호출 여부까지 확인할 수 있게 기록을 남긴다.
final class StubNotificationSettingUseCase: NotificationSettingUseCase, @unchecked Sendable {
    var isOnValue = false
    var activation: PermissionActivation = .activated
    private(set) var didTurnOff = false

    init(isOn: Bool = false, activation: PermissionActivation = .activated) {
        self.isOnValue = isOn
        self.activation = activation
    }

    func isOn() async -> Bool { isOnValue }

    func turnOn() async -> PermissionActivation { activation }

    func turnOff() async { didTurnOff = true }
}

struct StubLocationSettingUseCase: LocationSettingUseCase {
    var isOnValue = false
    var activation: PermissionActivation = .activated

    func isOn() async -> Bool { isOnValue }
    func turnOn() async -> PermissionActivation { activation }
}

/// 이번 실행에서 마지막으로 읽은 프로필을 정해 주는 스텁. 기본은 "아직 한 번도 못 읽음"(nil).
struct StubLastKnownProfileUseCase: LastKnownProfileUseCase {
    var profile: Profile?

    func execute() -> Profile? { profile }
}

/// 테스트가 쓰는 최소 deps 묶음. Coordinator 배선 테스트에서 쓴다.
struct StubProfileDeps: ProfileDeps {
    var fetchProfile: FetchProfileUseCase = StubFetchProfileUseCase()
    var lastKnownProfile: LastKnownProfileUseCase = StubLastKnownProfileUseCase()
    var updateProfile: UpdateProfileUseCase = StubUpdateProfileUseCase()
    var notificationSetting: NotificationSettingUseCase = StubNotificationSettingUseCase()
    var locationSetting: LocationSettingUseCase = StubLocationSettingUseCase()
}
