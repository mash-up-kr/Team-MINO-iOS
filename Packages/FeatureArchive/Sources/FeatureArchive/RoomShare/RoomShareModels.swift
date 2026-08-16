import Foundation

/// 공유 대상으로 고를 수 있는 방 한 건. 서버 연동 전까지 쓰는 화면 전용 표시 모델.
struct RoomShareRoom: Identifiable, Equatable {
    let id: String
    let name: String
    let memo: String
    let locationCount: Int

    var locationCountText: String { "장소 \(locationCount)개" }
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
        RoomShareRoom(id: "room-\($0)", name: "내 방", memo: "내가 꾹 저장한 장소", locationCount: 0)
    }
}
