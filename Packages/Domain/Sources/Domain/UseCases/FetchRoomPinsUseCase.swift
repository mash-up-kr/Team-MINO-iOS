import Foundation

/// 저장된 장소를 조회한다 — 방 상세 목록·지도와 방 리스트 탭 지도가 쓴다.
///
/// **정렬·카테고리 필터는 서버가 한다.** 화면은 고른 기준을 그대로 넘기고 받은 순서를 그린다 —
/// PRD 「목록 정렬 기준」이 *"후보 선정과 순위는 서버가 정하고 앱은 받은 순서대로 그린다"*,
/// *"재정렬하지도, 걸러내지도 않는다 … 앱이 구현할 계약이 아니다"* 로 못박았다.
///
/// 홈 덱(``FetchHomeCardsUseCase``)과 나눠 둔다 — 그쪽은 라벨 4종으로 채운 덱이고 이쪽은 목록이다.
public protocol FetchRoomPinsUseCase: Sendable {
    /// - Parameters:
    ///   - roomID: `nil` 이면 내가 속한 모든 방(방 리스트 탭 지도).
    ///   - origin: `sort == .distance` 일 때 필수.
    func execute(
        roomID: String?,
        sort: PinSort,
        category: PlaceCategoryFilter,
        origin: Coordinate?
    ) async throws -> [Pin]
}

public struct DefaultFetchRoomPinsUseCase: FetchRoomPinsUseCase {
    private let repository: PinRepository

    public init(repository: PinRepository) {
        self.repository = repository
    }

    public func execute(
        roomID: String?,
        sort: PinSort,
        category: PlaceCategoryFilter,
        origin: Coordinate?
    ) async throws -> [Pin] {
        try await repository.pins(roomID: roomID, sort: sort, category: category, origin: origin)
    }
}
