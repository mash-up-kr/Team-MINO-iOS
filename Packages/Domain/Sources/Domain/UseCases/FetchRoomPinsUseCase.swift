import Foundation

/// 방에 저장된 장소를 전부 조회한다 — 방 상세 목록·지도가 쓴다.
///
/// 홈 덱(``FetchHomeCardsUseCase``)과 나눠 둔다: 이쪽은 **거르지 않은 전부**라
/// 화면이 정렬·필터를 자기 규칙으로 적용할 수 있다.
public protocol FetchRoomPinsUseCase: Sendable {
    func execute(room: Room) async throws -> [Pin]
}

public struct DefaultFetchRoomPinsUseCase: FetchRoomPinsUseCase {
    private let repository: PinRepository

    public init(repository: PinRepository) {
        self.repository = repository
    }

    public func execute(room: Room) async throws -> [Pin] {
        try await repository.pins(roomID: room.id)
    }
}
