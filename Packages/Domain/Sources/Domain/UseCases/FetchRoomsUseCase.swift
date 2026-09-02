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
        let rooms = try await repository.rooms()
        // 방 목록에서 개인방을 맨 앞에 둔다 — 정렬은 UI 관심사가 아니라 "어느 방이 먼저
        // 보여야 하는가"라는 비즈니스 규칙이라 Repository 가 아니라 UseCase 에 둔다
        // (.claude/docs/clean-architecture.md — Repository 는 접근만, UseCase 가 비즈니스 흐름).
        //
        // 근거(슬랙 2026-09-01): 서버(박민수)는 생성일 최신순으로만 내려주고, 후처리는 클라이언트
        // 몫으로 합의됐다. 디자인(이영): "처음 디폴트방은 내 장소이구 그 후는 생성일순".
        //
        // 공동방(.shared)끼리의 방향(서버 최신순 유지 vs 오래된순)은 아직 디자인 확인 대기 —
        // 이번엔 서버가 준 순서(최신순)를 그대로 유지한다. 확인되면 이 주석과 함께 갱신한다.
        //
        // `sorted(by:)` 는 안정성(stable)이 보장되지 않아 두 그룹 각각의 상대 순서가 무너질 수
        // 있다. `filter` 두 번을 이어 붙이는 방식은 각 그룹 내부 순서를 그대로 보존한다.
        let personalRooms = rooms.filter { $0.type == .personal }
        let otherRooms = rooms.filter { $0.type != .personal }
        return personalRooms + otherRooms
    }
}
