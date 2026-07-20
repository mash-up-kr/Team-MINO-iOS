/// 로그 심각도. 낮음(`debug`)에서 높음(`error`) 순서로 정의된다.
/// `Comparable` 이라 백엔드가 "이 레벨 이상만 남긴다"는 최소 레벨 필터에 쓴다.
public enum LogLevel: Int, Sendable, Comparable {
    case debug
    case info
    case notice
    case warning
    case error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
