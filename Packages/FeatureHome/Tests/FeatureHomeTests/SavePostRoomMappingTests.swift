import DesignSystem
import Domain
import Foundation
import SavePostUI
import Testing
@testable import FeatureHome

/// 시트에 뜨는 방 한 줄이 도메인 값에서 어떻게 파생되는지 — 조건이 세 갈래라 여기서 고정한다.
struct SavePostRoomMappingTests {
    private func room(
        type: RoomType,
        name: String,
        description: String? = nil,
        color: String,
        pinCount: Int = 0
    ) -> Room {
        Room(
            id: "room-1", type: type, name: name, description: description,
            color: color, ownerId: "owner", inviteCode: "CODE",
            createdAt: Date(timeIntervalSince1970: 0),
            pinCount: pinCount, memberCount: 1, users: []
        )
    }

    @Test("개인방 이름은 서버 값과 무관하게 '내 장소'로 고정된다")
    func personalRoomNameIsFixed() {
        let mapped = SavePostRoom(room(type: .personal, name: "나의 아지트", color: "#00BDDE"))
        #expect(mapped.name == "내 장소")
    }

    @Test("공동방 이름은 서버 값 그대로 — 뱃지와 달리 '방' 접미사를 붙이지 않는다")
    func sharedRoomNameHasNoSuffix() {
        let source = room(type: .shared, name: "매쉬업 화이팅", color: "#FFC06E")
        let mapped = SavePostRoom(source)
        #expect(mapped.name == "매쉬업 화이팅")
        // 같은 방이라도 홈 뱃지 표기는 "…방" 이라 서로 다르다 — 시안 차이를 고정해 둔다.
        #expect(source.homeDisplayName == "매쉬업 화이팅방")
    }

    @Test("메모·장소 수·id 는 도메인 값을 그대로 옮긴다")
    func passesThroughDescriptionAndCounts() {
        let mapped = SavePostRoom(
            room(type: .shared, name: "언젠가 가야지", description: "저장만 하고 안 간 곳들",
                 color: "#FFC06E", pinCount: 3)
        )
        #expect(mapped.id == "room-1")
        #expect(mapped.memo == "저장만 하고 안 간 곳들")
        #expect(mapped.placeCount == 3)
    }

    @Test("메모가 없는 방은 memo 가 nil 이라 시트가 한 줄로 그린다")
    func nilDescriptionStaysNil() {
        #expect(SavePostRoom(room(type: .shared, name: "내 방", color: "#FFC06E")).memo == nil)
    }

    @Test("방 색이 팔레트에 있으면 그 색 썸네일을 쓴다")
    func thumbnailUsesRoomColor() {
        #expect(SavePostRoom(room(type: .shared, name: "방", color: "#FFC06E")).thumbnail == .color(.orange))
        #expect(SavePostRoom(room(type: .personal, name: "방", color: "#0098B2")).thumbnail == .color(.cyan))
    }

    @Test("팔레트에 없는 색은 my-room 썸네일로 떨어진다")
    func thumbnailFallsBackToMyRoom() {
        // 서버가 피커 밖의 색을 주더라도 빈 자리가 뜨지 않아야 한다.
        #expect(SavePostRoom(room(type: .shared, name: "방", color: "#123456")).thumbnail == .myRoom)
    }
}
