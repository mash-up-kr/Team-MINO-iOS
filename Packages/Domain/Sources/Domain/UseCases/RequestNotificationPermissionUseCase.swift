/// 아직 권한을 정하지 않은 사용자에게 알림 권한을 **한 번만** 묻는다.
///
/// 마이페이지 스위치는 사용자가 찾아 들어가야 있어 있는 줄 모르는 사람이 많다. 그래서 새로 설치한
/// 사용자에게는 이미 권한을 묻는 자리 — 저장 탭에 처음 들어가 위치를 묻는 순간 — 에 이어 붙인다
/// (``RequestEntryPermissionsUseCase``). 이미 쓰던 사용자는 지금까지처럼 스위치를 눌렀을 때 묻는다.
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
