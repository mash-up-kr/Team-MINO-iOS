import Foundation
import Testing
@testable import Domain

private let owner = MemberID("u1")
private let stranger = MemberID("u9")

private func member(_ id: String, isOwner: Bool = false) -> RoomMember {
    RoomMember(
        userId: id, nickname: "멤버 \(id)", avatarColor: nil,
        isOwner: isOwner, joinedAt: Date(timeIntervalSince1970: 0)
    )
}

private func room(type: RoomType = .shared, users: [RoomMember] = [member("u1", isOwner: true)]) -> Room {
    Room(
        id: "room-1", type: type, name: "방", description: nil, color: .orange,
        ownerId: owner.value, createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: users.count, users: users
    )
}

struct RoomOwnershipTests {
    @Test("신원이 방 주인과 같으면 방장이다")
    func ownedByOwner() {
        #expect(room().isOwned(by: owner))
    }

    @Test("방 주인이 아니면 방장이 아니다")
    func rejectsStranger() {
        #expect(!room().isOwned(by: stranger))
    }

    @Test("신원을 모르면 방장이 아니다")
    func rejectsUnknownViewer() {
        #expect(!room().isOwned(by: nil))
    }
}

struct RoomKindTests {
    @Test("공동방만 isShared 다")
    func sharedRoom() {
        #expect(room(type: .shared).isShared)
        #expect(!room(type: .personal).isShared)
    }
}

struct RoomLeaveTests {
    @Test("방장이 마지막 멤버면 나갈 때 방이 사라진다")
    func ownerAloneDeletesRoom() {
        #expect(room().deletesWhenLeft(by: owner))
    }

    @Test("방장이라도 다른 멤버가 남으면 방은 유지된다")
    func ownerWithMembersKeepsRoom() {
        let crowded = room(users: [member("u1", isOwner: true), member("u2")])
        #expect(!crowded.deletesWhenLeft(by: owner))
    }

    @Test("방장이 아니면 혼자 남아 있어도 방은 유지된다")
    func strangerNeverDeletesRoom() {
        #expect(!room().deletesWhenLeft(by: stranger))
        #expect(!room().deletesWhenLeft(by: nil))
    }
}

struct RoomOwnerTransferTests {
    @Test("위임 후보에서 방장 본인은 빠진다")
    func excludesOwner() {
        let crowded = room(users: [member("u1", isOwner: true), member("u2"), member("u3")])
        #expect(crowded.ownerTransferCandidates.map(\.userId) == ["u2", "u3"])
    }

    @Test("멤버가 방장뿐이면 후보가 없다")
    func noCandidatesWhenAlone() {
        #expect(room().ownerTransferCandidates.isEmpty)
    }
}
