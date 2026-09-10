import Foundation

/// 방의 **참여** 자체를 다루는 저장소 — 나가기와 방장 위임.
///
/// 방 정보 편집(``RoomEditingRepository``)과 나눠 둔다. 그쪽은 방이라는 대상의 속성을 고치고,
/// 이쪽은 "누가 이 방에 속해 있는가" 를 바꾼다 — 권한도 실패 모양도 다르다.
public protocol RoomMembershipRepository: Sendable {
    /// 이 방에서 나간다.
    ///
    /// 서버 규칙(스펙 `DELETE /rooms/{roomId}/members/me`): 일반 멤버는 그대로 나가고,
    /// **방장은 다른 멤버가 남아 있으면 거절된다**(``DomainError/ownerTransferRequired``).
    /// 방장이 마지막 멤버면 나가기가 곧 **방 삭제**다 — 그래서 별도의 방 삭제 API 가 없다.
    func leave(roomId: String) async throws

    /// 방장을 넘긴다. 방장만 부를 수 있다.
    func transferOwner(roomId: String, nextOwnerId: String) async throws
}
