import Domain
import RoomCreationUI
import SavePostUI

extension SavePostRoom {
    /// 익스텐션이 받은 방(`Domain.Room`) → 게시물 저장 시트 표시용 값.
    ///
    /// **`FeatureHome` 의 같은 이름 매핑과 짝이다.** 익스텐션은 `Feature*` 를 링크할 수 없어
    /// (공유 UI 레이어의 금지 의존) 코드를 함께 쓰지 못한다. 색 매핑은 ``RoomColorPalette`` 를
    /// 양쪽이 함께 부르므로 어긋나지 않지만(색 미선택은 양쪽 다 my-room 으로 폴백), **개인방 이름은 이 문자열이 홈의
    /// `Room.personalHomeName` 과 어긋나면 같은 방이 두 화면에서 다른 이름으로 보인다.**
    /// 문구를 바꾸면 둘 다 바꾼다.
    init(_ room: Room) {
        self.init(
            id: room.id,
            name: room.type == .personal ? "내 장소" : room.name,
            memo: room.description,
            placeCount: room.pinCount,
            thumbnail: room.color.flatMap(RoomColorPalette.thumbnail(for:)).map { .color($0) } ?? .myRoom
        )
    }
}
