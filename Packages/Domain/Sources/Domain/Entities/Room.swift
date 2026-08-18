import Foundation

/// 고유 식별자(id)로 구분되는 도메인 Entity — 저장된 "방".
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct Room: Equatable, Identifiable, Sendable {
    public let id: RoomID
    public let type: RoomType
    public let name: String
    public let description: String?
    /// 방 대표 색(hex). 표시 매핑은 Feature 계층이 담당한다.
    public let color: String
    public let ownerId: String
    public let inviteCode: String
    public let createdAt: Date
    /// 저장된 장소 수("장소 N개").
    public let pinCount: Int
    public let memberCount: Int
    public let users: [RoomMember]

    public init(
        id: RoomID,
        type: RoomType,
        name: String,
        description: String?,
        color: String,
        ownerId: String,
        inviteCode: String,
        createdAt: Date,
        pinCount: Int,
        memberCount: Int,
        users: [RoomMember]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.color = color
        self.ownerId = ownerId
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.pinCount = pinCount
        self.memberCount = memberCount
        self.users = users
    }
}
