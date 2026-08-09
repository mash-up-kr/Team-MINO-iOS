import Foundation

/// 하나의 비즈니스 유스케이스 = 하나의 UseCase.
/// UI 관심사(화면 상태, 네비게이션)를 포함하지 않는다.
public protocol FetchRoomsUseCase: Sendable {
    func execute() async throws -> [Room]
}

public struct DefaultFetchRoomsUseCase: FetchRoomsUseCase {
    private let repository: RoomRepository

    public init(repository: RoomRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Room] {
        try await repository.rooms()
    }
}
