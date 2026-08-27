import Domain
import RoomCreationUI
import SavePostUI

extension SavePostRoom {
    /// 익스텐션이 받은 방(`Domain.Room`) → 게시물 저장 시트 표시용 값.
    ///
    /// **`FeatureHome` 의 같은 이름 매핑과 짝이다.** 익스텐션은 `Feature*` 를 링크할 수 없어
    /// (공유 UI 레이어의 금지 의존) 코드를 함께 쓰지 못한다. 대신 갈리면 안 되는 두 규칙 —
    /// 개인방 이름(``Room/personalDisplayName``)과 색 매핑(``RoomColorPalette``) — 은 양쪽이
    /// 같은 것을 부르므로 한쪽만 바뀔 수 없다.
    init(_ room: Room) {
        self.init(
            id: room.id,
            name: room.type == .personal ? Room.personalDisplayName : room.name,
            memo: room.description,
            placeCount: room.pinCount,
            thumbnail: room.color.flatMap(RoomColorPalette.thumbnail(for:)).map { .color($0) } ?? .myRoom
        )
    }
}
