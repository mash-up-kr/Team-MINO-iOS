import Foundation

/// 지금 앱을 쓰는 사람의 신원을 가져온다.
///
/// 화면이 "내 것인지"를 판정하는 데 쓴다 — 내가 쓴 코멘트에만 삭제 아이콘을 붙이거나,
/// 내가 방장인 방에서만 방 편집 항목을 보이는 식이다. 판정 규칙 자체는 화면이 아니라
/// 이 값을 받은 reduce 가 정한다.
public protocol CurrentMemberUseCase: Sendable {
    func execute() async throws -> MemberProfile
}

public struct DefaultCurrentMemberUseCase: CurrentMemberUseCase {
    private let repository: CurrentMemberRepository

    public init(repository: CurrentMemberRepository) {
        self.repository = repository
    }

    public func execute() async throws -> MemberProfile {
        try await repository.currentMember()
    }
}
