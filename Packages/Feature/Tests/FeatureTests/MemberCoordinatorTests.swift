import Testing
import Domain
@testable import Feature

private let fixture = Member(id: MemberID("1"), name: "홍길동", email: "hong@example.com")

private struct StubFetchMember: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member { fixture }
}

private struct StubDeps: MemberDeps {
    var fetchMember: FetchMemberUseCase = StubFetchMember()
}

@MainActor
struct MemberCoordinatorTests {
    @Test("goToDetail nav → path 에 detail 이 push 된다")
    func navigate_pushes_detail() {
        let coord = MemberCoordinator(deps: StubDeps(), memberID: MemberID("1"))

        coord.handle(.goToDetail(fixture.id))   // 라우팅 직접 검증 (구독과 분리돼 결정적)

        #expect(coord.path == [.detail(fixture.id)])
    }

    @Test("presentEdit nav → 자식 생성 + sheet present")
    func navigate_presents_edit_child() {
        let coord = MemberCoordinator(deps: StubDeps(), memberID: MemberID("1"))

        coord.handle(.presentEdit)

        #expect(coord.sheet == .edit)
        #expect(coord.editChild != nil)
    }

    @Test("자식 편집 결과를 부모가 받아 반영하고 자식을 해제한다")
    func edit_finish_reflected() {
        let coord = MemberCoordinator(deps: StubDeps(), memberID: MemberID("1"))
        coord.editChild = MemberEditCoordinator()

        coord.editDidFinish(.saved("새이름"))

        #expect(coord.lastEditResult == .saved("새이름"))
        #expect(coord.editChild == nil)
    }
}
