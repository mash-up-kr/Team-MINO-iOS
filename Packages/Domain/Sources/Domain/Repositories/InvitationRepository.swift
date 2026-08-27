import Foundation

/// 도메인 관점에서 방 초대에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol InvitationRepository: Sendable {
    /// 이 방에서 쓰는 **내** 초대 코드.
    ///
    /// 멤버당 하나뿐이라 여러 번 불러도 같은 값이 온다(만료·재발급 없음). 그래서
    /// "발급"이 아니라 "얻는다"로 이름 붙였고, 호출부가 캐시할 이유도 없다.
    func inviteCode(roomId: String) async throws -> String
}
