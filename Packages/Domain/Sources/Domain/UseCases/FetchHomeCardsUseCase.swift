import Foundation

/// 홈 카드 덱에 표시할 장소를 조회한다 — 서버가 조회 기준(필터 칩)으로 골라 준 한 덱.
public protocol FetchHomeCardsUseCase: Sendable {
    /// - Parameter origin: 내 위치. `filter == .nearby` 에서만 쓰인다 — 없으면 서버가 거절하므로
    ///   호출부가 좌표를 먼저 확보하고 넘긴다.
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin]
}

public struct DefaultFetchHomeCardsUseCase: FetchHomeCardsUseCase {
    private let repository: PinRepository

    public init(repository: PinRepository) {
        self.repository = repository
    }

    public func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] {
        try await repository.cards(roomID: room.id, filter: filter, origin: origin)
    }
}
