import Foundation

/// 앱 자체 설정. 지금은 알림 발송 설정 하나뿐이라 값 하나만 든다.
public protocol AppSettingsRepository: Sendable {
    /// 앱 자체 알림 발송 설정. OS 알림 권한과 **별개**로, 스위치를 끈 사실을 기억한다(FR-014).
    func isNotificationDeliveryEnabled() -> Bool
    func setNotificationDeliveryEnabled(_ enabled: Bool)
}
