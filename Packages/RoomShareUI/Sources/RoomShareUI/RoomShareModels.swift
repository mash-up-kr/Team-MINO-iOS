import Domain

public struct RoomShareRoom: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let memo: String
    public let locationCount: Int

    public var locationCountText: String { "장소 \(locationCount)개" }
}

public extension RoomShareRoom {
    init(from room: Room) {
        self.init(
            id: room.id,
            name: room.name,
            memo: room.description ?? "",
            locationCount: room.pinCount
        )
    }
}

/// 공유 시트의 방 선택 상태. 다중 선택이며, 하나도 안 고르면 전송할 수 없다.
/// View 밖 순수 타입이라 단위 테스트로 규칙을 고정한다.
public struct RoomShareSelection: Equatable {
    public private(set) var ids: Set<RoomShareRoom.ID> = []

    /// 아무것도 고르지 않은 상태로 시작한다.
    public init() {}

    public var canSubmit: Bool { !ids.isEmpty }

    public func contains(_ id: RoomShareRoom.ID) -> Bool { ids.contains(id) }

    public mutating func toggle(_ id: RoomShareRoom.ID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }
}
