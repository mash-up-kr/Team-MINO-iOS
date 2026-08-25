import Foundation

/// 홈 카드 덱에 표시할 핀(저장한 장소)을 조회한다.
/// 하나의 비즈니스 유스케이스 = 하나의 UseCase. UI 관심사(화면 상태, 네비게이션)를 포함하지 않는다.
/// 방은 식별자(RoomID)로만 참조한다 — aggregate 통째가 아니라 identity 로 경계를 넘는다.
public protocol FetchPinsUseCase: Sendable {
    /// 방 id 목록과 조회 기준(필터 칩)을 받아, 각 방의 핀을 목록 순서대로 이어붙인 평면 배열을 반환한다.
    /// 기준이 바뀌면 그 기준으로 걸러진 목록을 새로 받는다(필터링 주체는 서버).
    func execute(roomIDs: [RoomID], filter: PinFilter) async throws -> [Pin]
    /// 특정 방의 다음 페이지(이미 본 장소 제외분)를 반환한다. page 는 0 부터 시작하는 페이지 커서.
    func execute(roomID: RoomID, page: Int, filter: PinFilter) async throws -> [Pin]
}

public struct DefaultFetchPinsUseCase: FetchPinsUseCase {
    private let repository: PinRepository

    public init(repository: PinRepository) {
        self.repository = repository
    }

    public func execute(roomIDs: [RoomID], filter: PinFilter) async throws -> [Pin] {
        try await repository.pins(roomIDs: roomIDs, filter: filter)
    }

    public func execute(roomID: RoomID, page: Int, filter: PinFilter) async throws -> [Pin] {
        try await repository.pins(roomID: roomID, page: page, filter: filter)
    }
}
