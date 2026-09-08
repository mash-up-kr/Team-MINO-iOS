import Foundation

/// 이 기기의 푸시 토큰을 서버의 내 계정에 붙인다.
///
/// **해제(삭제) 메서드가 없다.** 서버에 삭제 엔드포인트가 없어서다 — 끄기는 기기 쪽에서 토큰을
/// 무효화하는 방식으로 이뤄진다(``PushRegistrationRepository``). 서버에 DELETE 가 생기면 그때 추가한다.
public protocol PushTokenRepository: Sendable {
    func register(token: String) async throws
}

/// 이 기기의 현재 푸시 토큰을 얻는 창구. 구현은 SDK 를 타므로 컴포지션 루트에 있다.
public protocol PushTokenProvider: Sendable {
    /// 얻지 못하면 nil. **던지지 않는다** — 토큰은 이 경로 말고 SDK 갱신 콜백으로도 오고,
    /// 실패를 사용자에게 보여줄 화면이 없다.
    func currentToken() async -> String?
}
