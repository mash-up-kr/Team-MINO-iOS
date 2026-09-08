import Domain
import Foundation
import Testing
@testable import FeatureArchive

/// 헤더 표시 모델이 도메인 방에서 무엇을 가져오는지 — 특히 `isPersonal` 은 헤더에서 `+`(초대)와
/// `⋮`(더보기)를 지우는 유일한 근거라 매핑을 고정한다.
struct RoomDetailRoomTests {
    private func room(type: RoomType, pinCount: Int = 3) -> Room {
        Room(
            id: "r1", type: type, name: "우리 동네 맛집", description: "메모", color: .orange,
            ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: pinCount, memberCount: 2, users: []
        )
    }

    // PRD 「개인방」 = 초대 불가 · 삭제/나가기 금지, 시안 `004-5` Case 3 = 더보기 버튼 없음.
    @Test("개인방은 isPersonal 이 켜진다")
    func isPersonal_personalRoom() {
        #expect(RoomDetailRoom(from: room(type: .personal)).isPersonal)
    }

    @Test("공동방은 isPersonal 이 꺼진다 — 초대·더보기가 붙는 쪽이다")
    func isPersonal_sharedRoom() {
        #expect(RoomDetailRoom(from: room(type: .shared)).isPersonal == false)
    }

    // 장소를 지운 뒤 헤더를 다시 만들 때 방 종류를 잃으면, 개인방에 없던 `+`·`⋮` 가 되살아난다.
    @Test("장소를 하나 지워도 방 종류는 남는다")
    func removingOneLocation_keepsRoomKind() {
        let shrunk = RoomDetailRoom(from: room(type: .personal)).removingOneLocation()

        #expect(shrunk.isPersonal)
        #expect(shrunk.locationCount == 2)
    }
}
