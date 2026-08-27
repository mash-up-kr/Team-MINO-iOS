import Foundation

/// 사용자 세션에 접근하는 추상 인터페이스.
/// 인증 수단(익명 인증·소셜 로그인 등)이 무엇인지 Domain 은 알지 못한다.
public protocol AuthRepository: Sendable {
    /// 세션을 확보한다. 이미 있으면 그대로 돌려주고, 없을 때만 새로 만든다.
    /// 앱 진입마다 불리므로 **이미 있을 때 네트워크를 타지 않아야 한다.**
    func ensureSession() async throws -> UserSession
}
