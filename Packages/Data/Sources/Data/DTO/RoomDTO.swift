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
    /// 스펙: "최근 핀 최대 4개의 장소 대표 이미지 URL(최신순). **저장된 핀이 없으면 방 대표 색상 키 1개**".
    /// 한 배열에 두 의미가 섞여 오므로 `toDomain()` 이 URL 만 남긴다.
    let thumbnailList: [String]?
}

/// `?showUsers=true` 로 조회했을 때만 실리는 방 멤버.
struct RoomMemberDTO: Decodable {
    let userId: String
    let nickname: String
    /// 스펙상 nullable — 아바타를 아직 안 고른 계정이 있다. 타입은 프로필 응답과 같은
    /// ``AvatarDTO``(`{ "color": … }`) 를 재사용한다.
    let avatar: AvatarDTO?
    let isOwner: Bool
    let joinedAt: Date
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
    ///
    /// - Parameter members: 멤버를 **응답 밖에서** 받아 왔을 때 넘긴다(단건 상세는 `users` 를 주지
    ///   않아 `RoomAPI.members` 를 따로 부른다). `nil` 이면 응답의 `users` 를 쓴다.
    func toDomain(members: [RoomMemberDTO]? = nil) -> Room {
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
            users: (members ?? users ?? []).map { $0.toDomain() },
            placeThumbnails: placeThumbnails()
        )
    }

    /// `thumbnailList` 에서 **사진 URL 만** 골라 낸다. 색상 키는 버린다 — 색은 `color` 로 이미 온다.
    /// 거르는 규칙과 그 이유는 ``webImageURL(_:)`` 에 있다.
    private func placeThumbnails() -> [URL] {
        (thumbnailList ?? []).compactMap { webImageURL($0) }
    }
}

extension RoomMemberDTO {
    func toDomain() -> RoomMember {
        RoomMember(
            userId: userId,
            nickname: nickname,
            // 모르는 색은 "아바타 없음" 으로 떨군다 — 방 목록 전체의 디코딩을 깨뜨리는 것보다 낫다
            // (`ProfileDTO.toDomain()` 과 같은 판단).
            avatarColor: avatar?.color.flatMap(AvatarColor.init(rawValue:)),
            isOwner: isOwner,
            joinedAt: joinedAt
        )
    }
}
