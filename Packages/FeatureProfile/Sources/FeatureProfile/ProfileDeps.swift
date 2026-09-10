import Domain

// [Convention] .claude/docs/mvi-coordinator-di.md §4 — Coordinator 별 좁은 deps 프로토콜, 자기 의존만 담는다.
public protocol ProfileDeps {
    var fetchProfile: FetchProfileUseCase { get }
    /// 첫 프레임을 채울 값 — 서버를 기다리지 않는다(``ProfileMainState/init(profile:)``).
    var lastKnownProfile: LastKnownProfileUseCase { get }
    var updateProfile: UpdateProfileUseCase { get }
    var notificationSetting: NotificationSettingUseCase { get }
    var locationSetting: LocationSettingUseCase { get }
}
