import Foundation

/// 멤버의 신원 표시 정보 — 코멘트 작성자·핀 저장자에 붙는 읽기 전용 스냅샷.
/// 식별자를 갖지만 값으로 비교하므로 VO 로 둔다(서버가 준 시점의 표시값이며 클라이언트가 고치지 않는다).
///
/// `RoomMember` 와 합치지 않는다 — 그쪽은 `isOwner`·`joinedAt` 을 들어 **방 안에서의 멤버십**을
/// 표현하는 개념이고, 이쪽은 **누구인지**만 말한다.
public struct MemberProfile: Equatable, Hashable, Sendable {
    public let id: MemberID
    public let nickname: String
    /// 아바타 색. 서버가 신원에 붙여 주는 유일한 아바타 계약이다(`avatar.color`) — 방 멤버
    /// (``RoomMember/avatarColor``)와 같은 어휘라 두 경로로 받은 같은 사람이 같은 얼굴로 그려진다.
    /// 아직 색을 고르지 않았거나 서버 팔레트가 우리보다 앞서 나갔으면 nil 이다.
    /// 색↔그림 매핑은 표시 관심사라 Feature/DesignSystem 이 정한다.
    public let avatarColor: AvatarColor?

    public init(id: MemberID, nickname: String, avatarColor: AvatarColor?) {
        self.id = id
        self.nickname = nickname
        self.avatarColor = avatarColor
    }
}
