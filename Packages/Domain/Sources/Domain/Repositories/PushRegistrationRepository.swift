import Foundation

/// 원격 알림(APNs) 등록/해제.
///
/// iOS 는 앱 프로세스가 도착한 원격 알림의 표시를 막을 수 없다 — Android 처럼 수신 지점에서
/// 버리는 방식이 성립하지 않는다. 그래서 "앱 자체 알림 발송 설정"(FR-014)을 끄는 실제 수단은
/// **APNs 등록을 해제해 기기 토큰을 무효화하는 것**이다. OS 알림 권한은 그대로 유지된다.
public protocol PushRegistrationRepository: Sendable {
    func register() async
    func unregister() async
}
