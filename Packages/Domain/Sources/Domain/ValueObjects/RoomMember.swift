import Foundation

/// 방에 속한 멤버. 식별자(userId)로 구분되지만, 방 목록에서는 값으로 다루므로 VO 로 둔다.
/// 불변이며 프레임워크에 의존하지 않는다.
public struct RoomMember: Equatable, Sendable {
    public let userId: String
    public let nickname: String
    public let avatarID: Int
    public let isOwner: Bool
    public let joinedAt: Date

    public init(userId: String, nickname: String, avatarID: Int, isOwner: Bool, joinedAt: Date) {
        self.userId = userId
        self.nickname = nickname
        self.avatarID = avatarID
        self.isOwner = isOwner
        self.joinedAt = joinedAt
    }
}
