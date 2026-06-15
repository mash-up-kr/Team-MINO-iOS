import XCTest
@testable import Domain

private final class StubMemberRepository: MemberRepository {
    let result: Result<Member, DomainError>
    init(result: Result<Member, DomainError>) { self.result = result }
    func member(id: MemberID) async throws -> Member {
        try result.get()
    }
}

final class FetchMemberUseCaseTests: XCTestCase {
    func test_execute_returnsMemberFromRepository() async throws {
        let expected = Member(id: MemberID("1"), name: "민호", email: nil)
        let sut = DefaultFetchMemberUseCase(repository: StubMemberRepository(result: .success(expected)))

        let member = try await sut.execute(id: MemberID("1"))

        XCTAssertEqual(member, expected)
    }

    func test_execute_propagatesDomainError() async {
        let sut = DefaultFetchMemberUseCase(repository: StubMemberRepository(result: .failure(.memberNotFound)))

        do {
            _ = try await sut.execute(id: MemberID("404"))
            XCTFail("에러가 전파되어야 한다")
        } catch let error as DomainError {
            XCTAssertEqual(error, .memberNotFound)
        } catch {
            XCTFail("DomainError 가 아닌 오류: \(error)")
        }
    }
}
