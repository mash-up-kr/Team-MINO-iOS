import Domain
import FirebaseMessaging
import Logging
import UIKit

/// `PushRegistrationRepository` 의 iOS 구현.
///
/// iOS 는 앱이 도착한 원격 알림의 표시를 막을 수 없어, "앱 자체 알림 발송 설정"(FR-014)을 끄는
/// 실제 수단이 **APNs 등록 해제**다. 기기 토큰이 무효화돼 푸시가 오지 않고, OS 알림 권한은
/// 허용된 채로 남는다 — 스위치를 다시 켜면 시스템 팝업 없이 재등록된다.
///
/// FCM 자동 초기화(AutoInit)도 여기서 스위치에 묶는다. Domain 에 `setAutoInit(_:)` 같은 구멍을
/// 뚫지 않는 건 그게 이 어댑터의 내부 사정이기 때문이다 — Domain 이 FCM 을 알게 된다.
///
/// `register()` 는 **프로세스마다 한 번은 불려야 한다.** 스위치를 켜는 순간뿐 아니라 앱 진입에서도
/// `SyncPushTokenUseCase` 가 토큰을 묻기 전에 부른다 — 등록 없이는 APNs 토큰이 없어 FCM 이
/// 발급을 거부한다. 멱등이라 두 경로가 각자 불러도 무해하다.
@MainActor
struct RemoteNotificationRegistrationRepository: PushRegistrationRepository {
    func register() async {
        // [진단] 이 호출이 실제로 나갔는지 확인할 길이 없었다 — 등록이 안 된 것과 등록은 됐는데
        // 도착 콜백이 안 오는 것이 밖에서 똑같아 보인다. 원인이 잡히면 걷어낸다.
        Log.info("APNs 등록 요청")
        UIApplication.shared.registerForRemoteNotifications()
        // 이 값은 SDK 가 UserDefaults 에 남겨 **다음 실행에도 유지**되고 Info.plist 의 false 를
        // 덮는다 — 한 번 켠 사용자는 콜드런치마다 토큰을 자동으로 받는다.
        Messaging.messaging().isAutoInitEnabled = true
    }

    func unregister() async {
        Messaging.messaging().isAutoInitEnabled = false
        // 삭제를 APNs 해제보다 **먼저** 한다 — 해제한 뒤엔 SDK 가 FCM 서버와 통신할 근거를 잃는다.
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            Log.warning("FCM 토큰 삭제 실패", metadata: ["reason": String(describing: error)])
        }
        UIApplication.shared.unregisterForRemoteNotifications()

        // ⚠️ 서버에는 토큰 삭제 API 가 없어(`PUT`만 있다) **내 유저 행의 토큰 문자열은 남는다.**
        //    끄기의 실효는 그 토큰이 무효가 돼 발송이 실패하는 데서 난다. DELETE 가 생기면 여기서
        //    함께 부른다.
    }
}
