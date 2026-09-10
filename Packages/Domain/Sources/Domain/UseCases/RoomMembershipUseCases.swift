/// 이 방에서 나간다(004-5 "방 나가기").
///
/// 방장이 다른 멤버를 남긴 채 부르면 ``DomainError/ownerTransferRequired`` 로 거절된다 —
/// 화면은 그 신호를 받아 위임 대상을 고르게 한다.
public protocol LeaveRoomUseCase: Sendable {
    func execute(roomId: String) async throws
}

public struct DefaultLeaveRoomUseCase: LeaveRoomUseCase {
    private let repository: RoomMembershipRepository

    public init(repository: RoomMembershipRepository) {
        self.repository = repository
    }

    public func execute(roomId: String) async throws {
        try await repository.leave(roomId: roomId)
    }
}

/// 방장을 다른 참여자에게 넘긴다. 방장이 방을 나가기 위한 선행 절차다.
public protocol TransferRoomOwnerUseCase: Sendable {
    func execute(roomId: String, nextOwnerId: String) async throws
}

public struct DefaultTransferRoomOwnerUseCase: TransferRoomOwnerUseCase {
    private let repository: RoomMembershipRepository

    public init(repository: RoomMembershipRepository) {
        self.repository = repository
    }

    public func execute(roomId: String, nextOwnerId: String) async throws {
        try await repository.transferOwner(roomId: roomId, nextOwnerId: nextOwnerId)
    }
}
