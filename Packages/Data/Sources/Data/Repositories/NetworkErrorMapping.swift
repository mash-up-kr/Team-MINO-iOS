import Domain
import Networking

extension NetworkError {
    /// 401 을 도메인 어휘로 나눈다.
    ///
    /// 서버는 **미등록도 401 로** 준다(404 가 아니다) — 둘을 가르는 건 `errorCode` 뿐이다.
    /// 인증이 깨진 것과 "아직 가입 전"은 사용자가 할 일이 완전히 달라(재로그인 vs 온보딩)
    /// 여기서 반드시 나눈다.
    var unauthorizedReason: DomainError {
        errorCode == NetworkError.userNotRegisteredCode ? .notRegistered : .unauthorized
    }
}
