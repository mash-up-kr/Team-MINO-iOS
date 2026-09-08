import FirebaseMessaging
import Foundation

/// FCM 등록 토큰을 받는 `MessagingDelegate`.
///
/// 토큰은 **비동기·반복적으로** 온다(설치 직후, 갱신, 복원). 그래서 "스위치를 켤 때 한 번 올린다"
/// 만으로는 부족하고 이 채널이 함께 있어야 한다.
///
/// 토큰은 `token` 으로 흘러나간다 — 소비자가 늦게 꽂히는 사정은 ``PendingHandoff`` 주석 참조.
@MainActor
final class PushTokenObserver: NSObject, MessagingDelegate {
    let token = PendingHandoff<String>()

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // 토큰 삭제 직후에는 nil 로 온다 — 올릴 것이 없다.
        guard let fcmToken else { return }
        Task { @MainActor in self.token.deliver(fcmToken) }
    }
}
