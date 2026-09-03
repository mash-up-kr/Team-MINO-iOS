import Foundation

/// 방에 속한 멤버. 식별자(userId)로 구분되지만, 방 목록에서는 값으로 다루므로 VO 로 둔다.
/// 불변이며 프레임워크에 의존하지 않는다.
public struct RoomMember: Equatable, Sendable {
    public let userId: String
    public let nickname: String
    /// 아바타 팔레트 색. 서버가 팔레트에 없는 이름을 주거나 아직 아바타가 없으면 `nil` —
    /// 그리는 쪽이 기본 캐릭터로 폴백한다(`ProfileSetupUI.AvatarPalette`).
    public let avatarColor: AvatarColor?
    public let isOwner: Bool
    public let joinedAt: Date

    public init(userId: String, nickname: String, avatarColor: AvatarColor?, isOwner: Bool, joinedAt: Date) {
        self.userId = userId
        self.nickname = nickname
        self.avatarColor = avatarColor
        self.isOwner = isOwner
        self.joinedAt = joinedAt
    }
}
