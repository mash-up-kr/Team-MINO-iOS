import Foundation
import Testing
import Domain
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
        color: String = "#FED3F7",
        ownerId: String = "u1",
        inviteCode: String = "CODE1",
        createdAt: String = "2026-08-01T09:00:00Z",
        pinCount: Int = 0,
        memberCount: Int = 1,
        users: [RoomMemberDTO]? = nil
    ) -> RoomDTO {
        RoomDTO(
            id: id, type: type, name: name, description: description, color: color,
            ownerId: ownerId, inviteCode: inviteCode, createdAt: createdAt,
            pinCount: pinCount, memberCount: memberCount, users: users
        )
    }

    @Test("필드를 그대로 옮기고, users 가 nil 이면 빈 배열로 매핑한다")
    func mapsFieldsAndDefaultsNilUsersToEmpty() throws {
        let dto = makeDTO(users: nil)

        let room = dto.toDomain()

        #expect(room.id == RoomID("r1"))
        #expect(room.type == .personal)
        #expect(room.name == "내 장소")
        #expect(room.description == nil)
        #expect(room.color == "#FED3F7")
        #expect(room.ownerId == "u1")
        #expect(room.inviteCode == "CODE1")
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

    @Test("파싱 불가한 날짜 문자열은 epoch(1970-01-01) 로 폴백한다")
    func invalidDateFallsBackToEpoch() throws {
        let dto = makeDTO(createdAt: "not-a-real-date")

        let room = dto.toDomain()

        #expect(room.createdAt == Date(timeIntervalSince1970: 0))
    }

    @Test("정상 ISO8601 날짜는 그대로 파싱된다")
    func validDateParsesExactly() throws {
        let dto = makeDTO(createdAt: "2026-08-01T09:00:00Z")

        let room = dto.toDomain()

        // 독립적으로 계산한 고정 기준시각과 비교 — 프로덕션 파서 로직을 재사용하지 않는다.
        let expected = Date(timeIntervalSince1970: 1_785_574_800)
        #expect(room.createdAt == expected)
    }

    @Test("RoomMemberDTO 는 avatar.id 를 avatarID 로 평탄화해 매핑한다")
    func mapsRoomMemberFields() throws {
        let memberDTO = RoomMemberDTO(
            userId: "u2", nickname: "지훈", avatar: .init(id: 7),
            isOwner: false, joinedAt: "2026-08-03T13:00:00Z"
        )
        let dto = makeDTO(users: [memberDTO])

        let room = dto.toDomain()

        #expect(room.users.count == 1)
        #expect(room.users[0].userId == "u2")
        #expect(room.users[0].nickname == "지훈")
        #expect(room.users[0].avatarID == 7)
        #expect(room.users[0].isOwner == false)
    }
}
