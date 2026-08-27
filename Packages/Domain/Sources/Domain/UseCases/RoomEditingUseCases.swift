/// 공동방을 새로 만든다. 만든 사람이 방장이 된다.
public protocol CreateRoomUseCase: Sendable {
    func execute(name: String, description: String?, color: RoomColor) async throws -> Room
}

public struct DefaultCreateRoomUseCase: CreateRoomUseCase {
    private let repository: RoomEditingRepository

    public init(repository: RoomEditingRepository) {
        self.repository = repository
    }

    public func execute(name: String, description: String?, color: RoomColor) async throws -> Room {
        try await repository.create(name: name, description: description, color: color)
    }
}

/// 방 정보를 고친다. 서버가 방장만 허용한다.
public protocol UpdateRoomUseCase: Sendable {
    func execute(roomId: String, name: String, description: String?, color: RoomColor) async throws -> Room
}

public struct DefaultUpdateRoomUseCase: UpdateRoomUseCase {
    private let repository: RoomEditingRepository

    public init(repository: RoomEditingRepository) {
        self.repository = repository
    }

    public func execute(
        roomId: String,
        name: String,
        description: String?,
        color: RoomColor
    ) async throws -> Room {
        try await repository.update(roomId: roomId, name: name, description: description, color: color)
    }
}
