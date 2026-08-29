import Domain

/// 014 저장된 방 시트에 띄울 항목 — 어느 장소의 목록인지(`id`)와 그 방들.
///
/// 방 배열을 그대로 넘기지 않고 감싸는 이유는 두 가지다. `.sheet(item:)` 이 `Identifiable` 을
/// 요구하고, "어느 장소의 목록인가"가 곧 시트의 정체성이기 때문이다 — 다른 장소로 갈아타면
/// 같은 방들이 담겨 있어도 다른 시트다.
///
/// 표시 모델(``RoomListItem``)이 아니라 도메인 `Room` 을 담는다 — Nav 로 흐르는 값이라
/// `Sendable` 이어야 하는데 표시 모델은 `Image` 를 물고 있어 그 조건을 못 맞춘다.
public struct SavedRoomsPresentation: Identifiable, Equatable, Sendable {
    /// 이 목록이 어느 장소의 것인지(핀 id).
    public let id: String
    /// 장소가 중복 저장된 방들. 비어 있는 채로 만들지 않는다 — 진입 자체가 막힌다(reduce 가 가드).
    public let rooms: [Room]

    public init(id: String, rooms: [Room]) {
        self.id = id
        self.rooms = rooms
    }
}
