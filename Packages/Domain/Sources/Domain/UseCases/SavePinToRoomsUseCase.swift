import Foundation

/// 카드 더보기 → "다른 방 저장" 으로 고른 방들에 그 장소를 저장한다.
public protocol SavePinToRoomsUseCase: Sendable {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws
}

public struct DefaultSavePinToRoomsUseCase: SavePinToRoomsUseCase {
    private let repository: SavePinRepository

    public init(repository: SavePinRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID, roomIDs: Set<String>) async throws {
        guard !roomIDs.isEmpty else { return }
        try await repository.save(pinID: pinID, toRoomIDs: roomIDs)
    }
}
