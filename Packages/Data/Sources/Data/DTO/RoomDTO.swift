import Foundation
import Domain

/// DTO 날짜(ISO8601) 파싱. Swift6 Sendable 한 `ISO8601FormatStyle` 사용(공유 가변 상태 없음).
/// 파싱 불가 시 epoch(0)로 보수적 처리한다.
private func parseISO8601(_ string: String) -> Date {
    (try? Date(string, strategy: .iso8601)) ?? Date(timeIntervalSince1970: 0)
}

/// `GET /api/v1/rooms` 응답 래퍼(`{ data: RoomSummary[] }`).
struct RoomsResponseDTO: Decodable {
    let data: [RoomDTO]
}

/// API 스키마와 결합되는 DTO. internal 로 닫아 Domain 에 노출되지 않게 한다.
struct RoomDTO: Decodable {
    let id: String
    let type: String
    let name: String
    let description: String?
    let color: String
    let ownerId: String
    let inviteCode: String
    let createdAt: String
    let pinCount: Int
    let memberCount: Int
    let users: [RoomMemberDTO]?
}

struct RoomMemberDTO: Decodable {
    let userId: String
    let nickname: String
    let avatar: AvatarDTO
    let isOwner: Bool
    let joinedAt: String

    struct AvatarDTO: Decodable {
        let id: Int
    }
}

extension RoomDTO {
    /// 경계(Data → Domain) 변환. DTO 를 Entity 로 매핑한다.
    /// 알 수 없는 `type` 은 `shared` 로, 파싱 불가한 날짜는 epoch(0)로 보수적 처리한다.
    func toDomain() -> Room {
        Room(
            id: id,
            type: RoomType(rawValue: type) ?? .shared,
            name: name,
            description: description,
            color: color,
            ownerId: ownerId,
            inviteCode: inviteCode,
            createdAt: parseISO8601(createdAt),
            pinCount: pinCount,
            memberCount: memberCount,
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
            joinedAt: parseISO8601(joinedAt)
        )
    }
}
