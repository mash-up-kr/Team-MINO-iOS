import Foundation

/// 권한이 필요한 스위치를 켜려 한 결과.
public enum PermissionActivation: Equatable, Sendable {
    case activated
    /// 방금 뜬 시스템 팝업에서 사용자가 거부했다 — 화면은 OFF 를 유지한다.
    case rejected
    /// 이미 거부돼 시스템 팝업이 다시 뜨지 않는다 — 사유를 안내한 뒤 OS 설정 앱으로 보낸다(EC-003).
    case needsSystemSettings
}

/// 알림이 실제로 켜져 있는가 — OS 알림 권한 허용 AND 앱 자체 발송 설정(spec §2.3).
///
/// 스위치 표시값과 **푸시 토큰 업로드 게이트**(``SyncPushTokenUseCase``)가 같은 규칙을 보게 하려고
/// 밖으로 뺐다. 복제하면 "스위치는 꺼졌는데 토큰은 계속 올라가는" 상태가 조용히 생긴다(반대도 마찬가지).
/// 두 UseCase 가 서로를 주입받지 않는 이유이기도 하다 — 그러면 순환이 된다.
func isNotificationDeliveryOn(
    _ permissions: PermissionRepository,
    _ settings: AppSettingsRepository
) async -> Bool {
    await permissions.notificationStatus() == .granted && settings.isNotificationDeliveryEnabled()
}

/// 앱을 쓰는 흐름 안에서 알림 권한을 **한 번만** 묻는다.
///
/// 마이페이지 스위치는 사용자가 찾아 들어가야 있어 있는 줄 모르는 사람이 많다. 그렇다고 앱을 켜자마자
/// 맥락 없이 물으면 거부율이 높은데, **iOS 시스템 팝업은 설치당 한 번뿐**이라 거부되면 스위치를 눌러도
/// 다시 뜨지 않는다(``NotificationSettingUseCase/turnOn()`` 이 그때 `needsSystemSettings` 를 돌려준다).
/// 그래서 이미 권한을 묻는 자리 — 저장 탭에 처음 들어가 위치를 묻는 순간 — 에 이어 붙인다.
///
/// > **스위치의 `turnOn()` 을 그대로 부르면 안 된다.** 그쪽은 권한이 이미 허용돼 있으면 앱 발송 설정을
/// > 켜는데, 마이페이지에서 일부러 끈 사용자의 설정이 진입할 때마다 조용히 되살아난다.
/// > 여기서는 **미결정일 때만** 손댄다.
public protocol RequestNotificationPermissionUseCase: Sendable {
    /// 권한이 미결정이면 시스템 팝업을 띄우고, 허용되면 발송 설정과 푸시 등록까지 마친다.
    /// 이미 허용·거부로 정해졌으면 아무것도 하지 않는다.
    func execute() async
}

public struct DefaultRequestNotificationPermissionUseCase: RequestNotificationPermissionUseCase {
    private let permissions: PermissionRepository
    private let setting: NotificationSettingUseCase

    /// 허용 뒤에 할 일(발송 설정 ON · 푸시 등록)이 스위치와 똑같아 ``NotificationSettingUseCase`` 를
    /// 받아 그대로 쓴다. 같은 규칙을 복제하면 한쪽만 고쳐지는 날이 온다.
    public init(permissions: PermissionRepository, setting: NotificationSettingUseCase) {
        self.permissions = permissions
        self.setting = setting
    }

    public func execute() async {
        guard await permissions.notificationStatus() == .notDetermined else { return }
        _ = await setting.turnOn()
    }
}

/// 마이페이지 `알림 설정` 스위치의 비즈니스 규칙.
///
/// 표시값은 **OS 알림 권한 허용 AND 앱 자체 발송 설정**의 합성이다(spec §2.3).
/// 끄기는 OS 권한을 건드리지 않고 앱 쪽 발송만 멈춘다(FR-014).
public protocol NotificationSettingUseCase: Sendable {
    func isOn() async -> Bool
    func turnOn() async -> PermissionActivation
    func turnOff() async
}

public struct DefaultNotificationSettingUseCase: NotificationSettingUseCase {
    private let permissions: PermissionRepository
    private let settings: AppSettingsRepository
    private let push: PushRegistrationRepository

    public init(
        permissions: PermissionRepository,
        settings: AppSettingsRepository,
        push: PushRegistrationRepository
    ) {
        self.permissions = permissions
        self.settings = settings
        self.push = push
    }

    public func isOn() async -> Bool {
        await isNotificationDeliveryOn(permissions, settings)
    }

    public func turnOn() async -> PermissionActivation {
        let status = await permissions.notificationStatus()
        let resolved = status == .notDetermined ? await permissions.requestNotification() : status

        switch resolved {
        case .granted:
            // 권한이 어느 진입점에서 허용됐든 발송 설정 기본값은 ON 이다(spec §4 가정).
            settings.setNotificationDeliveryEnabled(true)
            await push.register()
            return .activated
        case .denied:
            return status == .notDetermined ? .rejected : .needsSystemSettings
        case .notDetermined:
            // 요청 뒤에도 미결정으로 남는 경로는 없지만, 남는다면 켜진 것이 아니므로 OFF 를 유지한다.
            return .rejected
        }
    }

    public func turnOff() async {
        settings.setNotificationDeliveryEnabled(false)
        await push.unregister()
    }
}
