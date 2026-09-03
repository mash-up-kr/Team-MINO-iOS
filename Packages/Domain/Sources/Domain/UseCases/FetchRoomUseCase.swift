import Foundation

/// 방 하나를 식별자로 조회한다. 목록(`FetchRoomsUseCase`)과 달리 대상이 이미 정해진 경우에 쓴다.
public protocol FetchRoomUseCase: Sendable {
    func execute(id: String) async throws -> Room
}

public struct DefaultFetchRoomUseCase: FetchRoomUseCase {
    private let repository: RoomDetailRepository

    public init(repository: RoomDetailRepository) {
        self.repository = repository
    }

    public func execute(id: String) async throws -> Room {
        try await repository.room(id: id)
    }
}
