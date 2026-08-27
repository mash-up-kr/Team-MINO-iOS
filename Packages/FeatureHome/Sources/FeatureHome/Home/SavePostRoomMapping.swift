import DesignSystem
import Domain
import RoomCreationUI
import SavePostUI

extension SavePostRoom {
    /// 홈이 든 방(`Domain.Room`) → 게시물 저장 시트 표시용 값.
    ///
    /// 이름은 개인방만 "내 장소"로 고정하고 공동방은 서버 이름을 그대로 쓴다 — 홈 뱃지·방 리스트의
    /// `homeDisplayName` 과 달리 시안(013-1-3)의 시트에는 "…방" 접미사가 없다.
    ///
    /// 썸네일은 방 색이 팔레트에 있으면 그 색 일러스트, 없으면 my-room 일러스트로 떨어진다
    /// (방 리스트 셀과 같은 폴백).
    init(_ room: Room) {
        self.init(
            id: room.id,
            name: room.type == .personal ? Room.personalHomeName : room.name,
            memo: room.description,
            placeCount: room.pinCount,
            thumbnail: room.color.map { .color(RoomColorPalette.thumbnail(for: $0)) } ?? .myRoom
        )
    }
}
