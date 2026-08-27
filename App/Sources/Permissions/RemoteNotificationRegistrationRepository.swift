import Domain
import UIKit

/// `PushRegistrationRepository` 의 iOS 구현.
///
/// iOS 는 앱이 도착한 원격 알림의 표시를 막을 수 없어, "앱 자체 알림 발송 설정"(FR-014)을 끄는
/// 실제 수단이 **APNs 등록 해제**다. 기기 토큰이 무효화돼 푸시가 오지 않고, OS 알림 권한은
/// 허용된 채로 남는다 — 스위치를 다시 켜면 시스템 팝업 없이 재등록된다.
///
/// > FCM 토큰을 서버에 올리지 않는다 — 등록 엔드포인트(`PUT /api/v1/users/me/push-token`)가
/// > 아직 서버에 없다. 푸시를 실제로 붙이는 PR 에서 함께 배선한다.
/// > 그 전까지는 `aps-environment` 엔타이틀먼트도 없어 `register()` 가 시스템 실패 콜백을 남긴다.
@MainActor
struct RemoteNotificationRegistrationRepository: PushRegistrationRepository {
    func register() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func unregister() async {
        UIApplication.shared.unregisterForRemoteNotifications()
    }
}
