import Domain
import Foundation

/// `AppSettingsRepository` 의 UserDefaults 구현. 플래그 하나뿐이라 별도 저장소를 두지 않는다.
///
/// 기본값은 `false` 다 — 알림 권한이 처음 허용되는 시점에만 `true` 로 올라간다(spec §4 가정).
///
/// `@unchecked Sendable`: UserDefaults 는 스레드 안전하다고 문서화돼 있지만 Sendable 로 표시돼 있지 않다.
public struct UserDefaultsAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private static let notificationDeliveryKey = "appSettings.notificationDeliveryEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isNotificationDeliveryEnabled() -> Bool {
        defaults.bool(forKey: Self.notificationDeliveryKey)
    }

    public func setNotificationDeliveryEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.notificationDeliveryKey)
    }
}
