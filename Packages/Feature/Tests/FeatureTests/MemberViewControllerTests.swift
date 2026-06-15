import XCTest
import Domain
@testable import Feature

private struct StubFetchMemberUseCase: FetchMemberUseCase {
    let member: Member
    func execute(id: MemberID) async throws -> Member { member }
}

final class MemberViewControllerTests: XCTestCase {
    @MainActor
    func test_viewDidLoad_doesNotCrashWithInjectedUseCase() {
        let stub = StubFetchMemberUseCase(member: Member(id: MemberID("1"), name: "민호", email: nil))
        let sut = MemberViewController(useCase: stub, memberID: MemberID("1"))

        sut.loadViewIfNeeded()

        XCTAssertNotNil(sut.view)
    }
}
