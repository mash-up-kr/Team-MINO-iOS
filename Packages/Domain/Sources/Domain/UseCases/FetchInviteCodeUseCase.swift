import Foundation

/// 친구를 부를 초대 코드를 얻는다.
///
/// 공유하기와 링크 복사가 **같은 코드**를 쓴다 — 코드가 멤버당 하나라 무엇으로 내보내든 값이 같다.
/// 코드를 링크로 조립하는 건 이 유스케이스의 몫이 아니다(링크 문법은 클라이언트 관심사).
public protocol FetchInviteCodeUseCase: Sendable {
    func execute(roomId: String) async throws -> String
}

public struct DefaultFetchInviteCodeUseCase: FetchInviteCodeUseCase {
    private let repository: InvitationRepository

    public init(repository: InvitationRepository) {
        self.repository = repository
    }

    public func execute(roomId: String) async throws -> String {
        try await repository.inviteCode(roomId: roomId)
    }
}
