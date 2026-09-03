import Domain
import RoomCreationUI
import SavePostUI

extension SavePostRoom {
    /// 홈이 들고 있는 방(`Domain.Room`) → 게시물 저장 시트(002-5 ②) 표시용 값.
    ///
    /// **`App/ShareExtension` 의 같은 이름 매핑과 짝이다.** 익스텐션은 `Feature*` 를 링크할 수 없어
    /// (공유 UI 레이어의 금지 의존) 코드를 함께 쓰지 못한다. 대신 갈리면 안 되는 두 규칙 —
    /// 개인방 이름(``Room/personalDisplayName``)과 색 매핑(``RoomColorPalette``) — 은 양쪽이
    /// 같은 것을 부르므로 한쪽만 바뀔 수 없다.
    ///
    /// > 방 이름에 "방" 접미사를 붙이는 ``Room/homeDisplayName`` 을 쓰지 않는다 — 그건 홈 뱃지·
    /// > 「홈 방 시트」의 표기 규칙(002-4-1 ③)이고, 게시물 저장 시트는 013-1-3 카드 그대로
    /// > 사용자가 지은 이름을 보여준다(익스텐션과 같은 화면이라 표기도 같아야 한다).
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
