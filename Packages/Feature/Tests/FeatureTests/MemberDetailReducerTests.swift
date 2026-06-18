import Testing
import Domain
import MVITestSupport
@testable import Feature

private let fixture = Member(id: MemberID("1"), name: "홍길동", email: "hong@example.com")

private struct StubFetchMember: FetchMemberUseCase {
    var result: Result<Member, DomainError> = .success(fixture)
    func execute(id: MemberID) async throws -> Member {
        switch result {
        case .success(let member): return member
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct MemberDetailReducerTests {
    private func makeStore(
        _ useCase: FetchMemberUseCase = StubFetchMember()
    ) -> TestStore<MemberDetailState, MemberDetailAction, MemberDetailNav> {
        TestStore(MemberDetailState(), reduce: memberDetailReducer(useCase: useCase, id: MemberID("1")))
    }

    @Test("L2 — load 하면 로딩 후 member 를 반영한다")
    func load_success() async {
        let store = makeStore()
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loaded(fixture)) {
            $0.member = fixture
            $0.isLoading = false
        }
        store.finish()
    }

    @Test("L2 — load 실패 시 errorMessage 를 채우고 로딩을 끈다")
    func load_failure() async {
        let store = makeStore(StubFetchMember(result: .failure(.memberNotFound)))
        await store.send(.load) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.loadFailed(.memberNotFound)) {
            $0.isLoading = false
            $0.errorMessage = "memberNotFound"
        }
        store.finish()
    }
}
