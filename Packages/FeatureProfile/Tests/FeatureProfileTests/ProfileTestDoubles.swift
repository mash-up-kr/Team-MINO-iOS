import Domain
@testable import FeatureProfile

/// 프로필 조회 결과를 정해 주는 스텁.
struct StubFetchProfileUseCase: FetchProfileUseCase {
    var profile: Profile = Profile(nickname: "홍길동", avatarID: 7)
    var error: DomainError?

    func execute() async throws -> Profile {
        if let error { throw error }
        return profile
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

/// 테스트가 쓰는 최소 deps 묶음. Coordinator 배선 테스트에서 쓴다.
struct StubProfileDeps: ProfileDeps {
    var fetchProfile: FetchProfileUseCase = StubFetchProfileUseCase()
    var saveProfile: SaveProfileUseCase = StubSaveProfileUseCase()
    var notificationSetting: NotificationSettingUseCase = StubNotificationSettingUseCase()
    var locationSetting: LocationSettingUseCase = StubLocationSettingUseCase()
}

struct StubSaveProfileUseCase: SaveProfileUseCase {
    func execute(nickname: String, avatarID: Int) async throws -> Profile {
        Profile(nickname: nickname, avatarID: avatarID)
    }
}
