import Foundation

/// 이 장소가 중복 저장된 방 한 칸 — 방과, **그 방 쪽 핀 id** (기획 014).
///
/// 방만 들지 않는 이유는 014 ② 가 "클릭 시, 해당 방의 장소상세로 이동한다" 이기 때문이다.
/// 같은 장소라도 방마다 핀이 따로라, 방 id 만으로는 열 핀을 집을 수 없다.
public struct SavedRoom: Equatable, Identifiable, Sendable {
    /// 목록의 정체성은 방이다 — 한 장소가 한 방에 두 번 담기지 않는다.
    public var id: String { room.id }
    public let room: Room
    /// 그 방에 담긴 이 장소의 핀. 서버가 매칭 핀을 주지 않은 경우에만 `nil` 이고,
    /// 그때 갈 수 있는 곳은 방 상세뿐이다.
    public let pinID: PinID?

    public init(room: Room, pinID: PinID?) {
        self.room = room
        self.pinID = pinID
    }
}
