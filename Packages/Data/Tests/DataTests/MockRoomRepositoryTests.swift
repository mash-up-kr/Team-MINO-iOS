import Foundation
import Testing
import Domain
@testable import Data

/// `MockRoomRepository` 는 하드코딩 JSON을 실제로 디코드해 `toDomain()` 경계 매핑을 태운다.
/// JSON 파싱이 깨지면(스키마 변경 등) 여기서 잡혀야 한다 — RoomListReducerTests 의 mock 은
/// Domain 레벨 fixture 라 이 디코딩 경로를 검증하지 못한다.
@Suite("MockRoomRepository")
struct MockRoomRepositoryTests {
    @Test("하드코딩 JSON 을 디코드해 4개의 Room 을 반환한다")
    func rooms_decodesFixtureJSON() async throws {
        let sut = MockRoomRepository()

        let rooms = try await sut.rooms()

        #expect(rooms.count == 4)
    }

    @Test("첫 번째 방(개인 방)이 personal 타입·안정 id 로 매핑된다")
    func rooms_firstRoomIsPersonalType() async throws {
        let sut = MockRoomRepository()

        let rooms = try await sut.rooms()
        let first = try #require(rooms.first)

        #expect(first.id == RoomID("00000000-0000-0000-0000-000000000001"))
        #expect(first.type == .personal)
        #expect(first.users.count == 1)
    }

    @Test("공유 방은 shared 타입이고 멤버가 2명 이상이다")
    func rooms_sharedRoomHasMultipleMembers() async throws {
        let sut = MockRoomRepository()

        let rooms = try await sut.rooms()
        let shared = try #require(rooms.first { $0.id == RoomID("00000000-0000-0000-0000-000000000002") })

        #expect(shared.type == .shared)
        #expect(shared.users.count == 3)
        #expect(shared.pinCount == 12)
    }
}
