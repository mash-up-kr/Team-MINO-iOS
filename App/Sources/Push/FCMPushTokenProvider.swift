import Domain
import FirebaseMessaging
import Logging

/// `PushTokenProvider` 의 FCM 구현.
///
/// 구현이 Data 가 아니라 App 에 있는 건 `FirebaseAuthRepository` 와 같은 이유다 —
/// SDK 어댑터는 컴포지션 루트가 갖는다.
///
/// > `token()` 은 **APNs 토큰이 아직 도착하지 않았으면 실패한다**(등록 직후가 그렇다).
/// > 실패를 삼키는 이유는 주 경로가 여기가 아니어서다 — 토큰은 `MessagingDelegate` 로도 오고,
/// > 그쪽이 같은 UseCase 를 뒤이어 부른다.
/// >
/// > **AutoInit 이 꺼져 있어도 이 호출은 토큰을 강제로 만든다.** 그래서 반드시 켜짐 게이트를
/// > 통과한 뒤에만 불려야 한다 — 순서는 `DefaultSyncPushTokenUseCase` 가 지킨다.
struct FCMPushTokenProvider: PushTokenProvider {
    func currentToken() async -> String? {
        do {
            return try await Messaging.messaging().token()
        } catch {
            Log.warning("FCM 토큰을 얻지 못했다", metadata: ["reason": String(describing: error)])
            return nil
        }
    }
}
