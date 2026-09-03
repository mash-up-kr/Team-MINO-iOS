import Foundation

/// 하나의 비즈니스 유스케이스 = 하나의 UseCase.
/// UI 관심사(화면 상태, 네비게이션)를 포함하지 않는다.
public protocol FetchMemberUseCase: Sendable {
    func execute(id: MemberID) async throws -> Member
}

public struct DefaultFetchMemberUseCase: FetchMemberUseCase {
    private let repository: MemberRepository

    public init(repository: MemberRepository) {
        self.repository = repository
    }

    public func execute(id: MemberID) async throws -> Member {
        try await repository.member(id: id)
    }
}
