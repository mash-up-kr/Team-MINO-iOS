import Domain
import Foundation
import Testing
@testable import FeatureArchive

/// 시안 `003-2` ⑤ 방 멤버 썸네일 규칙을 고정한다.
///
/// > 방 멤버 수에 따라 표시되며 최대 5개 이상 표시하지 않는다.
/// > 정렬(오른쪽 부터) 기준은 가장 최근에 위치를 저장한 사람 기준으로 우에서 좌로 정렬한다.
///
/// 순서가 뒤집혀도 화면에는 "아바타가 몇 개 겹쳐 있다" 로만 보여 눈으로는 못 잡는다 —
/// 실제로 이 규칙이 반영되기 전까지 **가장 오래된 멤버가 오른쪽 끝**에 서 있었다.
@MainActor
struct RoomListItemTests {
    /// 서버가 주는 순서 = 최근에 장소를 저장한 멤버가 앞
    /// (`GET /api/v1/rooms?showUsers=true` 스펙).
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

    // 6명 중 최신 5명만 남고, 가장 최신(서버 첫 번째)이 배열 **끝** = 화면 오른쪽 끝에 선다.
    // `MHAvatarGroup` 이 배열 앞을 왼쪽에 놓기 때문이다.
    @Test("003-2 ⑤ — 최신 5명만, 최신이 오른쪽 끝에 오도록 뒤집는다")
    func capsAtFiveAndReversesForRightMostLatest() {
        let colors = RoomListItem.memberAvatarColors(
            of: room(memberColors: [.red, .orange, .green, .blue, .pink, .brown])
        )

        #expect(colors == [.pink, .blue, .green, .orange, .red])
    }

    // 자르기와 뒤집기의 **순서**가 이 규칙의 함정이다. 뒤집고 나서 자르면
    // 최신 5명이 아니라 가장 오래된 5명이 남는데, 개수는 5로 같아 테스트 없이는 안 드러난다.
    @Test("003-2 ⑤ — 잘려 나가는 쪽은 가장 오래된 멤버다")
    func dropsOldestNotLatest() {
        let colors = RoomListItem.memberAvatarColors(
            of: room(memberColors: [.red, .orange, .green, .blue, .pink, .brown])
        )

        #expect(colors.contains(.red))       // 가장 최신 — 남는다
        #expect(!colors.contains(.brown))    // 가장 오래됨 — 떨어진다
    }

    @Test("003-2 ⑤ — 5명 이하는 자르지 않는다")
    func keepsAllWhenWithinLimit() {
        let colors = RoomListItem.memberAvatarColors(of: room(memberColors: [.red, .orange, .green]))

        #expect(colors == [.green, .orange, .red])
    }

    @Test("멤버가 없으면 아바타도 없다")
    func noMembersNoAvatars() {
        #expect(RoomListItem.memberAvatarColors(of: room(memberColors: [])).isEmpty)
    }
}
