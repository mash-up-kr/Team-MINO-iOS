import FirebaseAuth
import Networking

/// `AuthTokenProvider` 의 Firebase 구현. 서버에 보내는 건 UID 가 아니라 **ID 토큰**이다
/// — 서명된 JWT 라 서버가 위조를 검증할 수 있다.
///
/// 토큰 수명은 1시간이지만 `getIDToken()` 이 만료 임박분을 알아서 갱신하므로
/// **여기에 갱신 스케줄러나 타이머를 두지 않는다.** `refreshedToken()` 은 그 예측이
/// 빗나갔을 때(기기 시계 오차 등) 401 을 받고 나서만 쓰인다.
struct FirebaseAuthTokenProvider: AuthTokenProvider {
    func token() async -> String? {
        try? await Auth.auth().currentUser?.getIDToken()
    }

    func refreshedToken() async -> String? {
        try? await Auth.auth().currentUser?.getIDToken(forcingRefresh: true)
    }
}
