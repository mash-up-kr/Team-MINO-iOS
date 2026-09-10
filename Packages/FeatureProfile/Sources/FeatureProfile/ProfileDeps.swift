import Domain

// [Convention] .claude/docs/mvi-coordinator-di.md §4 — Coordinator 별 좁은 deps 프로토콜, 자기 의존만 담는다.
public protocol ProfileDeps {
    var fetchProfile: FetchProfileUseCase { get }
    /// 첫 프레임을 채울 값 — 서버를 기다리지 않는다(``ProfileMainState/init(profile:)``).
    var lastKnownProfile: LastKnownProfileUseCase { get }
    var updateProfile: UpdateProfileUseCase { get }
    var notificationSetting: NotificationSettingUseCase { get }
    /// 마이페이지 진입에서 알림 권한을 한 번 묻는다 — 업데이트 사용자의 진입점
    /// (``ProfileMainAction/requestNotificationPermissionOnEntry``).
    var requestNotificationPermission: RequestNotificationPermissionUseCase { get }
    var locationSetting: LocationSettingUseCase { get }
}
