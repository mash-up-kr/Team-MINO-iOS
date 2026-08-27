import Foundation

/// 요청에 실을 인증 토큰의 공급자.
///
/// **구현은 앱이 제공한다** — Networking 은 인증 수단(Firebase 등)을 알지 못한다.
/// 토큰을 못 얻으면 `nil` 을 돌려준다. 그 경우 요청은 `Authorization` 없이 나가고
/// 서버가 401 을 주며, 그 경로는 `NetworkError.unauthorized` 로 이미 정의돼 있다.
/// 여기서 던지지 않는 이유는 "토큰이 없다" 와 "서버가 거부했다" 를 한 갈래로 모아
/// 화면이 재인증 하나만 보게 하기 위해서다.
public protocol AuthTokenProvider: Sendable {
    /// 유효한 토큰. 세션이 없으면 nil.
    ///
    /// 만료가 임박한 토큰의 갱신은 구현이 알아서 한다(Firebase SDK 가 그렇게 동작한다).
    func token() async -> String?

    /// 강제로 새로 발급받은 토큰. **401 을 받은 뒤 재시도에만 쓴다.**
    func refreshedToken() async -> String?
}
