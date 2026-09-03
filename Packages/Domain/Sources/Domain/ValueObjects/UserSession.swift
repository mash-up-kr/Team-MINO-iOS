import Foundation

/// 로그인된 사용자의 세션. 식별자 하나로 동등성이 정해지는 값 객체다.
///
/// `userID` 가 무엇으로 발급됐는지(Firebase 익명 인증 등)는 Domain 이 알지 못한다.
/// **서버 인증에 이 값을 쓰지 않는다** — 요청에 실리는 건 별도의 토큰이고,
/// 그 공급은 Data/인프라 쪽 관심사다.
public struct UserSession: Equatable, Sendable {
    public let userID: String

    public init(userID: String) {
        self.userID = userID
    }
}
