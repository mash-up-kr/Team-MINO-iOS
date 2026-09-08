import Domain
import Foundation
import ProfileSetupUI
import Testing
@testable import FeatureArchive

/// 방 카드가 멤버 아바타를 몇 개 그리고 카운터에 몇 명을 남기는지 고정한다.
///
/// PRD 「방 멤버 아바타」 —
/// > **4명 이하**: 멤버 아바타를 있는 대로 모두 겹쳐 표시하고, 카운터는 붙이지 않는다.
/// > **5명 이상**: **아바타 3개 + 카운터 칩**으로 표시한다. 카운터는 아바타로 보이지 않는 나머지
/// > 인원 수다. (멤버 7명 → 아바타 3개 + `4`)
///
/// 시안 `003-2` ⑤ 는 "최대 5개 이상 표시하지 않는다"(카운터 없이 5개)로 적혀 있으나 **PRD 를
/// 따른다** — PRD 13.0.0 이 카운터 칩을 도입하며 경계를 4명으로 옮겼고, Android 구현 계약
/// (`docs/specs/room-list/data-model.md`)도 "`visibleAvatarUrls` 최대 4개" 로 같은 경계를 적었다.
///
/// 개수·순서 규칙 자체는 ``AvatarPalette/overlappedColors(_:)`` 가 소유하고 그 테스트가 순서까지
/// 단언한다. 여기서는 **방 카드가 그 규칙을 실제로 통과시키는지**만 본다.
@MainActor
struct RoomListItemTests {
    /// 서버가 주는 순서 = 최근에 장소를 저장한 멤버가 앞
    /// (`GET /api/v1/rooms?showUsers=true` 스펙: "최근에 장소를 저장한 멤버가 먼저").
    private func room(memberColors: [AvatarColor]) -> Room {
        Room(
            id: "r", type: .shared, name: "방", description: nil, color: .blue,
            ownerId: "u0", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0, memberCount: memberColors.count,
            users: memberColors.enumerated().map { index, color in
                RoomMember(
                    userId: "u\(index)", nickname: "n\(index)", avatarColor: color,
                    isOwner: index == 0, joinedAt: Date(timeIntervalSince1970: 0)
                )
            }
        )
    }

    @Test("4명 이하는 전부 그리고 카운터가 없다", arguments: [1, 2, 3, 4])
    func upToFourShowsAll(count: Int) {
        let colors = Array(repeating: AvatarColor.red, count: count)

        let item = RoomListItem(from: room(memberColors: colors))

        #expect(item.members.count == count)
        #expect(item.memberOverflow == nil)
    }

    // PRD 의 예시(멤버 7명 → 아바타 3개 + `4`)를 그대로 고정한다.
    @Test("7명은 아바타 3개 + 카운터 4다")
    func sevenMembers() {
        let colors: [AvatarColor] = [.red, .orange, .green, .blue, .pink, .brown, .cyan]

        let item = RoomListItem(from: room(memberColors: colors))

        #expect(item.members.count == 3)
        #expect(item.memberOverflow == 4)
    }

    // 경계는 5명이다 — 4명까지는 전부, 5명부터 접힌다. 개수만 보면 4와 5가 헷갈리는 자리다.
    @Test("경계는 5명이다")
    func boundaryAtFive() {
        let four = RoomListItem(from: room(memberColors: Array(repeating: .red, count: 4)))
        let five = RoomListItem(from: room(memberColors: Array(repeating: .red, count: 5)))

        #expect(four.members.count == 4)
        #expect(four.memberOverflow == nil)
        #expect(five.members.count == 3)
        #expect(five.memberOverflow == 2)
    }

    @Test("멤버가 없으면 아바타도 카운터도 없다")
    func noMembers() {
        let item = RoomListItem(from: room(memberColors: []))

        #expect(item.members.isEmpty)
        #expect(item.memberOverflow == nil)
    }
}
