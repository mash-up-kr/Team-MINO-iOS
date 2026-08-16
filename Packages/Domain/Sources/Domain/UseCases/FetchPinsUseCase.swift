import Foundation

/// 홈 카드 덱에 표시할 핀(저장한 장소)을 조회한다.
/// 하나의 비즈니스 유스케이스 = 하나의 UseCase. UI 관심사(화면 상태, 네비게이션)를 포함하지 않는다.
public protocol FetchPinsUseCase: Sendable {
    /// 방 목록을 받아, 각 방의 핀을 방 순서대로 이어붙인 평면 배열을 반환한다(초기 로드).
    func execute(rooms: [Room]) async throws -> [Pin]
    /// 특정 방의 다음 페이지(이미 본 장소 제외분)를 반환한다. page 는 0 부터 시작하는 페이지 커서.
    func execute(room: Room, page: Int) async throws -> [Pin]
}

public struct DefaultFetchPinsUseCase: FetchPinsUseCase {
    private let repository: PinRepository

    public init(repository: PinRepository) {
        self.repository = repository
    }

    public func execute(rooms: [Room]) async throws -> [Pin] {
        try await repository.pins(rooms: rooms)
    }

    public func execute(room: Room, page: Int) async throws -> [Pin] {
        try await repository.pins(room: room, page: page)
    }
}
