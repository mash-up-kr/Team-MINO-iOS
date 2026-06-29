import Testing
import Domain
@testable import Feature

/// 테스트용 UseCase 스텁. 결과를 주입해 성공/실패 분기를 검증한다.
private struct StubFetchMemberUseCase: FetchMemberUseCase {
    let result: Result<Member, DomainError>
    func execute(id: MemberID) async throws -> Member {
        try result.get()
    }
}

@MainActor
struct MemberProfileViewModelTests {
    private let member = Member(id: MemberID("1"), name: "민호", email: "mino@mash-up.kr")

    private func makeSUT(_ result: Result<Member, DomainError>) -> MemberProfileViewModel {
        MemberProfileViewModel(useCase: StubFetchMemberUseCase(result: result), memberID: MemberID("1"))
    }

    @Test func 초기상태는_idle이다() {
        #expect(makeSUT(.success(member)).state == .idle)
    }

    @Test func 로드_성공시_loaded_상태가_된다() async {
        let sut = makeSUT(.success(member))

        await sut.load()

        #expect(sut.state == .loaded(member))
    }

    @Test(arguments: [
        (DomainError.memberNotFound, "회원을 찾을 수 없어요"),
        (DomainError.unauthorized, "접근 권한이 없어요"),
        (DomainError.unknown, "회원 정보를 불러오지 못했어요"),
    ])
    func 로드_실패시_도메인오류가_사용자메시지로_매핑된다(_ error: DomainError, _ expected: String) async {
        let sut = makeSUT(.failure(error))

        await sut.load()

        #expect(sut.state == .failed(message: expected))
    }
}
