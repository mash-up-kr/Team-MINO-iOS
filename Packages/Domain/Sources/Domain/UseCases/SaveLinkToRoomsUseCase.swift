import Foundation

/// 공유받은 링크를 고른 방들에 저장한다.
public protocol SaveLinkToRoomsUseCase: Sendable {
    func execute(url: URL, roomIDs: Set<String>) async throws
}

public struct DefaultSaveLinkToRoomsUseCase: SaveLinkToRoomsUseCase {
    private let repository: SaveLinkRepository

    public init(repository: SaveLinkRepository) {
        self.repository = repository
    }

    public func execute(url: URL, roomIDs: Set<String>) async throws {
        try await repository.save(url: url, toRoomIDs: roomIDs)
    }
}
