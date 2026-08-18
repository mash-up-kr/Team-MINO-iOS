import Foundation
import Testing
@testable import Domain

@Suite("RoomOrdering — 개인방 우선 나열 정책")
struct RoomOrderingTests {
    private func room(_ id: String, type: RoomType) -> Room {
        Room(
            id: id,
            type: type,
            name: "방 \(id)",
            description: nil,
            color: "#00BDDE",
            ownerId: "user-1",
            inviteCode: "CODE\(id)",
            createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0,
            memberCount: 1,
            users: []
        )
    }

    @Test("개인방이 먼저, 공동방이 나중에 온다")
    func personalComesFirst() {
        let rooms = [room("s1", type: .shared), room("p1", type: .personal), room("s2", type: .shared)]
        #expect(RoomOrdering.personalFirst(rooms).map(\.id) == ["p1", "s1", "s2"])
    }

    @Test("각 그룹 안의 상대 순서는 입력 순서를 유지한다")
    func keepsRelativeOrderWithinGroups() {
        let rooms = [
            room("s1", type: .shared), room("p1", type: .personal),
            room("s2", type: .shared), room("p2", type: .personal),
        ]
        #expect(RoomOrdering.personalFirst(rooms).map(\.id) == ["p1", "p2", "s1", "s2"])
    }

    @Test("개인방만·공동방만·빈 배열은 그대로 통과한다")
    func passesThroughHomogeneousInput() {
        let personals = [room("p1", type: .personal), room("p2", type: .personal)]
        let shareds = [room("s1", type: .shared), room("s2", type: .shared)]
        #expect(RoomOrdering.personalFirst(personals).map(\.id) == ["p1", "p2"])
        #expect(RoomOrdering.personalFirst(shareds).map(\.id) == ["s1", "s2"])
        #expect(RoomOrdering.personalFirst([]).isEmpty)
    }
}
