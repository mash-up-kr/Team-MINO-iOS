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

/// 측위는 이 스위트의 관심사가 아니다 — 늘 좌표를 준다.
private struct StubCurrentLocationRepository: CurrentLocationRepository {
    func currentCoordinate() async -> Coordinate? { Coordinate(latitude: 37.4979, longitude: 127.0276) }
}

private final class SpyPushRegistration: PushRegistrationRepository, @unchecked Sendable {
    private(set) var didRegister = false
    private(set) var didUnregister = false
    func register() async { didRegister = true }
    func unregister() async { didUnregister = true }
}

// MARK: - 진입 시 알림 권한 요청

struct RequestNotificationPermissionUseCaseTests {
    private func make(
        permissions: FakePermissionRepository,
        settings: InMemoryAppSettingsRepository = InMemoryAppSettingsRepository(),
        push: SpyPushRegistration = SpyPushRegistration()
    ) -> DefaultRequestNotificationPermissionUseCase {
        DefaultRequestNotificationPermissionUseCase(
            permissions: permissions,
            setting: DefaultNotificationSettingUseCase(permissions: permissions, settings: settings, push: push)
        )
    }

    @Test("미결정이면 시스템 팝업을 띄운다 — 앱이 권한을 자동으로 묻는 유일한 자리다")
    func requestsWhenNotDetermined() async {
        let permissions = FakePermissionRepository(notification: .notDetermined)
        permissions.notificationAfterRequest = .granted

        await make(permissions: permissions).execute()

        #expect(permissions.didRequestNotification)
    }

    @Test("허용하면 발송 설정이 켜지고 푸시 등록까지 간다 — 스위치로 켠 것과 같은 결과다")
    func grantedTurnsOnDeliveryAndRegisters() async {
        let permissions = FakePermissionRepository(notification: .notDetermined)
        permissions.notificationAfterRequest = .granted
        let settings = InMemoryAppSettingsRepository()
        let push = SpyPushRegistration()

        await make(permissions: permissions, settings: settings, push: push).execute()

        #expect(settings.isNotificationDeliveryEnabled())
        #expect(push.didRegister)
    }

    /// 이 테스트가 지키는 것: 마이페이지에서 스위치를 **일부러 끈** 사용자가 저장 탭에 들어갈
    /// 때마다 발송이 조용히 되살아나면 안 된다. `turnOn()` 을 그냥 부르면 그렇게 된다.
    @Test("이미 허용된 상태에서는 아무것도 건드리지 않는다 — 꺼 둔 발송 설정이 되살아나지 않는다")
    func alreadyGrantedDoesNotReviveDelivery() async {
        let permissions = FakePermissionRepository(notification: .granted)
        let settings = InMemoryAppSettingsRepository(enabled: false)   // 스위치를 꺼 둔 상태
        let push = SpyPushRegistration()

        await make(permissions: permissions, settings: settings, push: push).execute()

        #expect(!settings.isNotificationDeliveryEnabled())
        #expect(!push.didRegister)
        #expect(!permissions.didRequestNotification)
    }

    @Test("이미 거부된 상태에서는 묻지 않는다 — 팝업이 뜨지도 않고, 부를 이유도 없다")
    func alreadyDeniedDoesNothing() async {
        let permissions = FakePermissionRepository(notification: .denied)
        let settings = InMemoryAppSettingsRepository()

        await make(permissions: permissions, settings: settings).execute()

        #expect(!permissions.didRequestNotification)
        #expect(!settings.isNotificationDeliveryEnabled())
    }
}

// MARK: - 저장 탭 진입 권한 묶음

struct RequestEntryPermissionsUseCaseTests {
    /// 알림 요청이 갔는지만 센다.
    private final class SpyNotificationRequest: RequestNotificationPermissionUseCase, @unchecked Sendable {
        private(set) var callCount = 0
        func execute() async { callCount += 1 }
    }

    private func make(
        permissions: FakePermissionRepository,
        notification: SpyNotificationRequest
    ) -> DefaultRequestEntryPermissionsUseCase {
        DefaultRequestEntryPermissionsUseCase(
            permissions: permissions,
            currentLocation: DefaultCurrentLocationUseCase(
                permissions: permissions,
                location: StubCurrentLocationRepository()
            ),
            requestNotification: notification
        )
    }

    @Test("위치가 미결정이면(= 새로 설치한 사용자) 위치 팝업 뒤에 알림도 잇는다")
    func locationPrompted_thenAsksNotification() async {
        let permissions = FakePermissionRepository(location: .notDetermined)
        permissions.locationAfterRequest = .granted
        let notification = SpyNotificationRequest()

        _ = await make(permissions: permissions, notification: notification).execute()

        #expect(permissions.didRequestLocation)
        #expect(notification.callCount == 1)
    }

    @Test("위치를 거부해도 알림은 잇는다 — 서로 다른 기능이다")
    func locationDeniedInPrompt_stillAsksNotification() async {
        let permissions = FakePermissionRepository(location: .notDetermined)
        permissions.locationAfterRequest = .denied
        let notification = SpyNotificationRequest()

        _ = await make(permissions: permissions, notification: notification).execute()

        #expect(notification.callCount == 1)
    }

    /// 이 테스트가 지키는 것: 업데이트 사용자에게 늘 보던 지도 위로 알림 팝업이 맥락 없이 뜨면 안 된다.
    /// 그들은 마이페이지 진입에서 묻는다.
    @Test("위치가 이미 허용돼 있으면(= 업데이트 사용자) 알림을 잇지 않는다")
    func locationAlreadyGranted_doesNotAskNotification() async {
        let permissions = FakePermissionRepository(location: .granted)
        let notification = SpyNotificationRequest()

        _ = await make(permissions: permissions, notification: notification).execute()

        #expect(!permissions.didRequestLocation)
        #expect(notification.callCount == 0)
    }

    @Test("위치가 이미 거부돼 있어도 알림을 잇지 않는다 — 팝업이 뜨지 않은 건 마찬가지다")
    func locationAlreadyDenied_doesNotAskNotification() async {
        let permissions = FakePermissionRepository(location: .denied)
        let notification = SpyNotificationRequest()

        _ = await make(permissions: permissions, notification: notification).execute()

        #expect(notification.callCount == 0)
    }
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
