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

    /// 개인방 표기 이름 — 서버가 주는 `name` 과 무관하게 개인방은 어느 화면에서든 이 문구로 부른다.
    ///
    /// 화면 문구지만 Domain 에 두는 이유는 **쓰는 쪽이 한 패키지가 아니기 때문**이다. 홈(`FeatureHome`)과
    /// 공유 익스텐션이 각자 이 이름을 붙이는데, 익스텐션은 `Feature*` 를 링크할 수 없어(공유 UI 레이어의
    /// 금지 의존) 홈의 상수를 함께 쓰지 못한다. 둘 다 볼 수 있는 가장 안쪽 자리가 여기다.
    public static let personalDisplayName = "내 장소"

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
