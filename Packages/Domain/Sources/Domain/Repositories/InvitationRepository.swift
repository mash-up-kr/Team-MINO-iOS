import Foundation

/// 도메인 관점에서 방 초대에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol InvitationRepository: Sendable {
    /// 이 방에서 쓰는 **내** 초대 코드.
    ///
    /// 멤버당 하나뿐이라 여러 번 불러도 같은 값이 온다(만료·재발급 없음). 그래서
    /// "발급"이 아니라 "얻는다"로 이름 붙였고, 호출부가 캐시할 이유도 없다.
    func inviteCode(roomId: String) async throws -> String

    /// 초대 코드가 가리키는 방. **인증이 필요 없다** — 온보딩 전에도 코드의 유효성을 확인할 수 있다.
    ///
    /// 합류 API 가 방 id 를 path 로 받으므로, 코드만 든 클라이언트에는 이 조회가 합류의 선행 단계다.
    func invitationPreview(code: String) async throws -> RoomInvitationPreview

    /// 초대 코드로 방에 합류한다. **이미 멤버여도 실패가 아니다**(서버가 멱등 응답을 준다) —
    /// 같은 링크를 두 번 눌러도 호출부가 중복을 방어할 필요가 없다.
    func joinRoom(roomId: String, inviteCode: String) async throws
}
