import Foundation

/// 초대 코드가 가리키는 방을 확인한다. **합류하기 전에** 부른다.
///
/// 두 가지를 한다 — 코드에서 방 id 를 풀고(합류 API 가 path 로 요구한다), 코드가 아직 살아 있는지
/// 가른다. 초대 유무가 온보딩 경로를 바꾸므로(공동방 생성·친구초대 스킵) **온보딩을 시작하기 전에**
/// 이 확인이 끝나야 한다. 무효한 코드로 스텝을 건너뛰면 방 없이 온보딩을 마치게 된다.
public protocol FetchInvitationPreviewUseCase: Sendable {
    func execute(code: String) async throws -> RoomInvitationPreview
}

public struct DefaultFetchInvitationPreviewUseCase: FetchInvitationPreviewUseCase {
    private let repository: InvitationRepository

    public init(repository: InvitationRepository) {
        self.repository = repository
    }

    public func execute(code: String) async throws -> RoomInvitationPreview {
        try await repository.invitationPreview(code: code)
    }
}

/// 초대 코드로 방에 합류한다.
///
/// 방 id 는 ``FetchInvitationPreviewUseCase`` 가 푼 값을 그대로 넘긴다 — 그래서 "코드가 이 방의
/// 것이 아님"(서버 400)이 구조적으로 생기지 않는다.
public protocol JoinRoomUseCase: Sendable {
    func execute(roomID: String, inviteCode: String) async throws
}

public struct DefaultJoinRoomUseCase: JoinRoomUseCase {
    private let repository: InvitationRepository

    public init(repository: InvitationRepository) {
        self.repository = repository
    }

    public func execute(roomID: String, inviteCode: String) async throws {
        try await repository.joinRoom(roomId: roomID, inviteCode: inviteCode)
    }
}
