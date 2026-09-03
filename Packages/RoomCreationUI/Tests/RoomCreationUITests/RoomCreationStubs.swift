import Domain
import Foundation

/// reduce 테스트용 UseCase 스텁. 무엇이 넘어왔는지 기록하고, 주입한 오류를 그대로 던진다.
///
/// `@unchecked Sendable` — 테스트는 단일 스레드(@MainActor)에서 순차 실행되고 기록은 그 뒤에 읽는다.
final class StubCreateRoomUseCase: CreateRoomUseCase, @unchecked Sendable {
    private(set) var received: (name: String, description: String?, color: RoomColor)?
    var error: Error?
    var result: Room = .stub()

    func execute(name: String, description: String?, color: RoomColor) async throws -> Room {
        received = (name, description, color)
        if let error { throw error }
        return result
    }
}

final class StubUpdateRoomUseCase: UpdateRoomUseCase, @unchecked Sendable {
    private(set) var received: (roomId: String, name: String, description: String?, color: RoomColor)?
    var error: Error?
    var result: Room = .stub()

    func execute(roomId: String, name: String, description: String?, color: RoomColor) async throws -> Room {
        received = (roomId, name, description, color)
        if let error { throw error }
        return result
    }
}

extension Room {
    static func stub(
        id: String = "room-1",
        name: String = "야호",
        description: String? = "야호호",
        color: RoomColor? = .red
    ) -> Room {
        Room(
            id: id,
            type: .shared,
            name: name,
            description: description,
            color: color,
            ownerId: "owner-1",
            createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0,
            memberCount: 1,
            users: []
        )
    }
}
