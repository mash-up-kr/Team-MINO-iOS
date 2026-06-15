import Foundation

/// 비즈니스 어휘로만 표현되는 도메인 오류.
/// 인프라(NetworkError 등) 오류는 Data 계층에서 이 타입으로 변환된다.
public enum DomainError: Error, Equatable, Sendable {
    case memberNotFound
    case unauthorized
    case unknown
}
