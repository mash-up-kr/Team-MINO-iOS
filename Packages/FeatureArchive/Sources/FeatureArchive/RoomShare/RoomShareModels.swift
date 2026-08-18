import Domain

struct RoomShareRoom: Identifiable, Equatable {
    let id: RoomID
    let name: String
    let memo: String
    let locationCount: Int

    var locationCountText: String { "장소 \(locationCount)개" }
}

extension RoomShareRoom {
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
struct RoomShareSelection: Equatable {
    private(set) var ids: Set<RoomShareRoom.ID> = []

    var canSubmit: Bool { !ids.isEmpty }

    func contains(_ id: RoomShareRoom.ID) -> Bool { ids.contains(id) }

    mutating func toggle(_ id: RoomShareRoom.ID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }
}

// MARK: - 더미 데이터

extension RoomShareRoom {
    static let samples: [RoomShareRoom] = (0..<5).map {
        RoomShareRoom(id: RoomID("room-\($0)"), name: "내 방", memo: "내가 꾹 저장한 장소", locationCount: 0)
    }
}
