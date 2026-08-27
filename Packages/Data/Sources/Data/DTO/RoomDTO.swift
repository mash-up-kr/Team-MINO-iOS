import Domain
import Foundation

/// API 스키마와 결합되는 DTO. internal 로 닫아 Domain 에 노출되지 않게 한다.
///
/// 목록(`GET /api/v1/rooms`)·생성(`POST`)·수정(`PATCH`) 응답을 한 타입으로 받는다.
/// 생성·수정 응답에는 `pinCount`·`memberCount`·`users` 가 없어서 옵셔널이다.
struct RoomDTO: Decodable {
    let id: String
    let type: String
    let name: String
    let description: String?
    let color: String
    let ownerId: String
    let createdAt: Date
    let pinCount: Int?
    let memberCount: Int?
    let users: [RoomMemberDTO]?
}

struct RoomMemberDTO: Decodable {
    let userId: String
    let nickname: String
    let avatar: AvatarDTO
    let isOwner: Bool
    let joinedAt: Date

    struct AvatarDTO: Decodable {
        let id: Int
    }
}

/// 방 생성(`POST`)·수정(`PATCH`) 요청 본문.
///
/// 수정은 스펙상 세 필드가 모두 옵셔널이지만 폼이 항상 전체 값을 들고 있어 그대로 다 보낸다 —
/// 그래서 두 요청이 같은 타입을 쓴다. 부분 수정이 필요해지면 그때 나눈다.
struct SaveRoomRequestDTO: Encodable, Sendable {
    let name: String
    let description: String?
    /// 서버는 hex 가 아니라 색 이름을 받는다 — 인코딩 지점을 여기 하나로 모은다.
    let color: String

    init(name: String, description: String?, color: RoomColor) {
        self.name = name
        self.description = description
        self.color = color.rawValue
    }
}

extension RoomDTO {
    /// 경계(Data → Domain) 변환. DTO 를 Entity 로 매핑한다.
    /// 알 수 없는 `type` 은 `shared`, 팔레트에 없는 `color` 는 `nil` 로 보수적 처리한다.
    func toDomain() -> Room {
        Room(
            id: id,
            type: RoomType(rawValue: type) ?? .shared,
            name: name,
            description: description,
            color: RoomColor(rawValue: color),
            ownerId: ownerId,
            createdAt: createdAt,
            pinCount: pinCount ?? 0,
            memberCount: memberCount ?? 0,
            users: (users ?? []).map { $0.toDomain() }
        )
    }
}

extension RoomMemberDTO {
    func toDomain() -> RoomMember {
        RoomMember(
            userId: userId,
            nickname: nickname,
            avatarID: avatar.id,
            isOwner: isOwner,
            joinedAt: joinedAt
        )
    }
}
