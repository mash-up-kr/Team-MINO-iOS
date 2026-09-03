import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// `RoomDTO.toDomain()` 경계 매핑 순수 로직 테스트.
/// DTO 는 internal 이라 이 파일(Data 테스트 타깃)에서만 만들 수 있다 — Domain 타깃에는 노출 안 함.
@Suite("RoomDTO → Room 매핑")
struct RoomDTOTests {
    private func makeDTO(
        id: String = "r1",
        type: String = "personal",
        name: String = "내 장소",
        description: String? = nil,
        color: String = "pink",
        ownerId: String = "u1",
        createdAt: Date = Date(timeIntervalSince1970: 1_785_574_800),
        pinCount: Int? = 0,
        memberCount: Int? = 1,
        users: [RoomMemberDTO]? = nil,
        hasPlace: Bool? = nil,
        thumbnailList: [String]? = nil
    ) -> RoomDTO {
        RoomDTO(
            id: id, type: type, name: name, description: description, color: color,
            ownerId: ownerId, createdAt: createdAt,
            pinCount: pinCount, memberCount: memberCount, users: users,
            hasPlace: hasPlace,
            thumbnailList: thumbnailList
        )
    }

    // 003-2 ④ — "해당 방에 포함되어있는 장소들의 이미지가 콜라주 형식으로 … 1개, 2개, 3개, 4개(최대)".
    @Test("thumbnailList 의 사진 URL 이 순서 그대로 실린다")
    func mapsPlaceThumbnails() throws {
        let dto = makeDTO(thumbnailList: [
            "https://cdn.example.com/a.jpg",
            "https://cdn.example.com/b.jpg",
        ])

        let room = dto.toDomain()

        #expect(room.placeThumbnails.map(\.absoluteString) == [
            "https://cdn.example.com/a.jpg",
            "https://cdn.example.com/b.jpg",
        ])
    }

    // 003-2 ③ — 장소가 0개면 서버가 같은 배열에 방 색상 키를 실어 보낸다. 사진으로 오인하면
    // 카드에 깨진 타일이 뜨므로 걸러야 한다(`URL(string: "orange")` 는 스킴 없이 성공한다).
    @Test("장소가 없어 색상 키만 온 경우는 사진 0장으로 떨어진다")
    func colorKeyIsNotAPhoto() throws {
        let dto = makeDTO(thumbnailList: ["orange"])

        let room = dto.toDomain()

        #expect(room.placeThumbnails.isEmpty)
    }

    @Test("thumbnailList 자체가 없는 응답은 사진 0장이다")
    func missingThumbnailListBecomesEmpty() throws {
        #expect(makeDTO(thumbnailList: nil).toDomain().placeThumbnails.isEmpty)
    }

    @Test("필드를 그대로 옮기고, users 가 nil 이면 빈 배열로 매핑한다")
    func mapsFieldsAndDefaultsNilUsersToEmpty() throws {
        let dto = makeDTO(users: nil)

        let room = dto.toDomain()

        #expect(room.id == "r1")
        #expect(room.type == .personal)
        #expect(room.name == "내 장소")
        #expect(room.description == nil)
        #expect(room.color == .pink)
        #expect(room.ownerId == "u1")
        #expect(room.pinCount == 0)
        #expect(room.memberCount == 1)
        #expect(room.users.isEmpty)
    }

    @Test("알 수 없는 type 문자열은 shared 로 보수적 폴백한다")
    func unknownTypeFallsBackToShared() throws {
        let dto = makeDTO(type: "enterprise")

        let room = dto.toDomain()

        #expect(room.type == .shared)
    }

    // 서버가 팔레트에 없는 색 이름을 줘도 방 자체는 살아야 한다 — 화면이 기본 썸네일로 폴백한다.
    @Test("팔레트에 없는 색 이름은 nil 로 떨어진다")
    func unknownColorFallsBackToNil() throws {
        let dto = makeDTO(color: "chartreuse")

        let room = dto.toDomain()

        #expect(room.color == nil)
    }

    // 생성·수정 응답에는 pinCount·memberCount 가 없다. 없으면 0 이어야 화면이 "장소 0개" 로 그린다.
    @Test("개수 필드가 빠진 응답은 0 으로 매핑한다")
    func missingCountsBecomeZero() throws {
        let dto = makeDTO(pinCount: nil, memberCount: nil)

        let room = dto.toDomain()

        #expect(room.pinCount == 0)
        #expect(room.memberCount == 0)
    }

    @Test("RoomMemberDTO 는 avatar.color 를 AvatarColor 로 평탄화해 매핑한다")
    func mapsRoomMemberFields() throws {
        let memberDTO = RoomMemberDTO(
            userId: "u2", nickname: "지훈", avatar: .init(color: "light_blue"),
            isOwner: false, joinedAt: Date(timeIntervalSince1970: 0)
        )
        let dto = makeDTO(users: [memberDTO])

        let room = dto.toDomain()

        #expect(room.users.count == 1)
        #expect(room.users[0].userId == "u2")
        #expect(room.users[0].nickname == "지훈")
        #expect(room.users[0].avatarColor == .lightBlue)
        #expect(room.users[0].isOwner == false)
    }

    // 아바타는 장식이라 없거나 모르는 색이어도 멤버를 통째로 버리지 않는다 — 얼굴만 기본으로 떨군다.
    @Test("아바타가 없거나 팔레트에 없는 색이면 avatarColor 는 nil 이다", arguments: [
        AvatarDTO?.none, AvatarDTO(color: nil), AvatarDTO(color: "chartreuse"),
    ])
    func unknownAvatarBecomesNil(_ avatar: AvatarDTO?) throws {
        let memberDTO = RoomMemberDTO(
            userId: "u3", nickname: "서연", avatar: avatar,
            isOwner: false, joinedAt: Date(timeIntervalSince1970: 0)
        )

        let room = makeDTO(users: [memberDTO]).toDomain()

        #expect(room.users[0].avatarColor == nil)
    }

    // 날짜 파싱은 이제 DTO 가 아니라 APIDecoder 의 몫이라, 디코딩 경로로 검증한다.
    @Test("ISO8601 문자열은 소수점 유무와 무관하게 디코드된다", arguments: [
        "2026-08-01T09:00:00Z",
        "2026-08-01T09:00:00.000Z",
    ])
    func decodesISO8601(_ raw: String) throws {
        let json = """
        {
          "id": "r1", "type": "shared", "name": "방", "description": null,
          "color": "pink", "ownerId": "u1", "createdAt": "\(raw)"
        }
        """

        let dto = try APIDecoder.make().decode(RoomDTO.self, from: Data(json.utf8))

        #expect(dto.toDomain().createdAt == Date(timeIntervalSince1970: 1_785_574_800))
    }
}
