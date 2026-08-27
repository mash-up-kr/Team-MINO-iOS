import Foundation

/// 비즈니스 어휘로만 표현되는 도메인 오류.
/// 인프라(NetworkError 등) 오류는 Data 계층에서 이 타입으로 변환된다.
public enum DomainError: Error, Equatable, Sendable {
    case memberNotFound
    case roomsFetchFailed
    /// 방을 만들거나 고치지 못했다.
    case roomSaveFailed
    case notificationsFetchFailed
    case unauthorized
    /// 세션을 확보하지 못했다. 인증 수단에 닿지 못한 경우(네트워크 단절 등)로,
    /// **서버가 거부한 `unauthorized` 와 구분한다** — 이쪽은 재시도가 의미 있다.
    case sessionUnavailable
    case unknown
}
