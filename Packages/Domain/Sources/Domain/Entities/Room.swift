import Foundation

/// 고유 식별자(id)로 구분되는 도메인 Entity — 저장된 "방".
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct Room: Equatable, Identifiable, Sendable {
    public let id: String
    public let type: RoomType
    public let name: String
    public let description: String?
    /// 방 대표 색. 서버가 팔레트에 없는 이름을 주면 `nil` — 그리는 쪽이 기본 썸네일로 폴백한다.
    public let color: RoomColor?
    public let ownerId: String
    public let createdAt: Date
    /// 저장된 장소 수("장소 N개").
    public let pinCount: Int
    public let memberCount: Int
    public let users: [RoomMember]

    public init(
        id: String,
        type: RoomType,
        name: String,
        description: String?,
        color: RoomColor?,
        ownerId: String,
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
        self.createdAt = createdAt
        self.pinCount = pinCount
        self.memberCount = memberCount
        self.users = users
    }
}
