import Testing
@testable import Domain

// MARK: - Test Doubles

/// OS 권한을 흉내 낸다. 요청이 실제로 발생했는지, 요청 후 무엇으로 바뀌는지를 시나리오마다 정한다.
private final class FakePermissionRepository: PermissionRepository, @unchecked Sendable {
    var notification: PermissionStatus
    var location: PermissionStatus
    /// 시스템 팝업에 사용자가 무엇을 답했는지 — 요청 뒤 상태.
    var notificationAfterRequest: PermissionStatus?
    var locationAfterRequest: PermissionStatus?
    private(set) var didRequestNotification = false
    private(set) var didRequestLocation = false

    init(notification: PermissionStatus = .notDetermined, location: PermissionStatus = .notDetermined) {
        self.notification = notification
        self.location = location
    }

    func notificationStatus() async -> PermissionStatus { notification }
    func locationStatus() async -> PermissionStatus { location }

    func requestNotification() async -> PermissionStatus {
        didRequestNotification = true
        notification = notificationAfterRequest ?? notification
        return notification
    }

    func requestLocation() async -> PermissionStatus {
        didRequestLocation = true
        location = locationAfterRequest ?? location
        return location
    }
}

private final class InMemoryAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private var enabled: Bool
    init(enabled: Bool = false) { self.enabled = enabled }
    func isNotificationDeliveryEnabled() -> Bool { enabled }
    func setNotificationDeliveryEnabled(_ value: Bool) { enabled = value }
}

private final class SpyPushRegistration: PushRegistrationRepository, @unchecked Sendable {
    private(set) var didRegister = false
    private(set) var didUnregister = false
    func register() async { didRegister = true }
    func unregister() async { didUnregister = true }
}

// MARK: - 알림

struct NotificationSettingUseCaseTests {
    private func make(
        permissions: FakePermissionRepository,
        settings: InMemoryAppSettingsRepository = InMemoryAppSettingsRepository(),
        push: SpyPushRegistration = SpyPushRegistration()
    ) -> DefaultNotificationSettingUseCase {
        DefaultNotificationSettingUseCase(permissions: permissions, settings: settings, push: push)
    }

    // 표시값은 둘의 AND 다(spec §2.3) — 어느 한쪽만 참이면 꺼져 보여야 한다.
    @Test("isOn — OS 권한과 앱 발송 설정이 모두 참일 때만 켜진다")
    func isOn_requiresBothPermissionAndDeliveryFlag() async {
        #expect(await make(
            permissions: FakePermissionRepository(notification: .granted),
            settings: InMemoryAppSettingsRepository(enabled: true)
        ).isOn())

        // 권한은 있는데 사용자가 앱에서 껐다(FR-014)
        #expect(await !make(
            permissions: FakePermissionRepository(notification: .granted),
            settings: InMemoryAppSettingsRepository(enabled: false)
        ).isOn())

        // 플래그는 켜져 있는데 OS 설정에서 권한을 뺏겼다
        #expect(await !make(
            permissions: FakePermissionRepository(notification: .denied),
            settings: InMemoryAppSettingsRepository(enabled: true)
        ).isOn())
    }

    @Test("turnOn — 미결정이면 요청하고, 허용되면 발송 플래그를 켜고 APNs 에 등록한다")
    func turnOn_whenNotDetermined_andGranted() async {
        let permissions = FakePermissionRepository(notification: .notDetermined)
        permissions.notificationAfterRequest = .granted
        let settings = InMemoryAppSettingsRepository()
        let push = SpyPushRegistration()

        let result = await make(permissions: permissions, settings: settings, push: push).turnOn()

        #expect(result == .activated)
        #expect(permissions.didRequestNotification)
        // 권한이 처음 허용되면 발송 설정 기본값은 ON 이다(spec §4 가정).
        #expect(settings.isNotificationDeliveryEnabled())
        #expect(push.didRegister)
    }

    // 방금 팝업에서 거부한 사용자를 설정 앱으로 보내면 안 된다 — 그냥 꺼진 채로 둔다.
    @Test("turnOn — 미결정에서 방금 거부하면 rejected 이고 아무것도 켜지 않는다")
    func turnOn_whenJustRejected() async {
        let permissions = FakePermissionRepository(notification: .notDetermined)
        permissions.notificationAfterRequest = .denied
        let settings = InMemoryAppSettingsRepository()
        let push = SpyPushRegistration()

        let result = await make(permissions: permissions, settings: settings, push: push).turnOn()

        #expect(result == .rejected)
        #expect(!settings.isNotificationDeliveryEnabled())
        #expect(!push.didRegister)
    }

    // 이미 거부된 상태에선 시스템 팝업이 다시 뜨지 않으므로 설정 앱으로 보내야 한다(EC-003).
    @Test("turnOn — 이미 거부돼 있으면 요청하지 않고 설정 이동을 요구한다")
    func turnOn_whenAlreadyDenied() async {
        let permissions = FakePermissionRepository(notification: .denied)

        let result = await make(permissions: permissions).turnOn()

        #expect(result == .needsSystemSettings)
        #expect(!permissions.didRequestNotification)
    }

    // 다른 진입점에서 이미 허용된 뒤 앱에서 껐다가 다시 켜는 경로 — 팝업이 뜨면 안 된다.
    @Test("turnOn — 이미 허용돼 있으면 요청 없이 발송 플래그만 켠다")
    func turnOn_whenAlreadyGranted_doesNotRequestAgain() async {
        let permissions = FakePermissionRepository(notification: .granted)
        let settings = InMemoryAppSettingsRepository(enabled: false)
        let push = SpyPushRegistration()

        let result = await make(permissions: permissions, settings: settings, push: push).turnOn()

        #expect(result == .activated)
        #expect(!permissions.didRequestNotification)
        #expect(settings.isNotificationDeliveryEnabled())
        #expect(push.didRegister)
    }

    // FR-014 — OS 권한은 그대로 두고 앱 쪽 발송만 멈춘다.
    @Test("turnOff — OS 권한은 건드리지 않고 발송 플래그만 내리며 APNs 등록을 해제한다")
    func turnOff_keepsPermission() async {
        let permissions = FakePermissionRepository(notification: .granted)
        let settings = InMemoryAppSettingsRepository(enabled: true)
        let push = SpyPushRegistration()

        await make(permissions: permissions, settings: settings, push: push).turnOff()

        #expect(!settings.isNotificationDeliveryEnabled())
        #expect(push.didUnregister)
        #expect(permissions.notification == .granted)   // 권한은 그대로
    }
}

// MARK: - 위치

struct LocationSettingUseCaseTests {
    // 알림과 달리 앱 자체 플래그가 없다 — 표시값이 곧 OS 권한이다(spec §2.3).
    @Test("isOn — OS 위치 권한 상태를 그대로 반영한다")
    func isOn_mirrorsPermission() async {
        #expect(await DefaultLocationSettingUseCase(
            permissions: FakePermissionRepository(location: .granted)
        ).isOn())
        #expect(await !DefaultLocationSettingUseCase(
            permissions: FakePermissionRepository(location: .denied)
        ).isOn())
    }

    @Test("turnOn — 미결정이면 요청하고, 허용되면 activated 다")
    func turnOn_whenNotDetermined_andGranted() async {
        let permissions = FakePermissionRepository(location: .notDetermined)
        permissions.locationAfterRequest = .granted

        let result = await DefaultLocationSettingUseCase(permissions: permissions).turnOn()

        #expect(result == .activated)
        #expect(permissions.didRequestLocation)
    }

    @Test("turnOn — 미결정에서 방금 거부하면 rejected 다")
    func turnOn_whenJustRejected() async {
        let permissions = FakePermissionRepository(location: .notDetermined)
        permissions.locationAfterRequest = .denied

        let result = await DefaultLocationSettingUseCase(permissions: permissions).turnOn()

        #expect(result == .rejected)
    }

    @Test("turnOn — 이미 거부돼 있으면 요청하지 않고 설정 이동을 요구한다")
    func turnOn_whenAlreadyDenied() async {
        let permissions = FakePermissionRepository(location: .denied)

        let result = await DefaultLocationSettingUseCase(permissions: permissions).turnOn()

        #expect(result == .needsSystemSettings)
        #expect(!permissions.didRequestLocation)
    }

    @Test("turnOn — 이미 허용돼 있으면 요청 없이 activated 다")
    func turnOn_whenAlreadyGranted() async {
        let permissions = FakePermissionRepository(location: .granted)

        let result = await DefaultLocationSettingUseCase(permissions: permissions).turnOn()

        #expect(result == .activated)
        #expect(!permissions.didRequestLocation)
    }
}
