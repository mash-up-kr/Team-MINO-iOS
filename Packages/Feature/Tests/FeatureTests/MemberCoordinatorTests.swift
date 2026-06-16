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

/// AsyncStream 구독(observe Task)이 비동기로 nav 를 처리하므로 조건 충족까지 잠깐 대기한다.
@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<200 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}

@MainActor
struct MemberCoordinatorTests {
    @Test("goToDetail nav → path 에 detail 이 push 된다")
    func navigate_pushes_detail() async {
        let coord = MemberCoordinator(deps: StubDeps(), memberID: MemberID("1"))
        let store = coord.makeMemberStore()

        store.send(.loaded(fixture))   // member 세팅(동기)
        store.send(.tapDetail)         // → navigate(.goToDetail)

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.detail(fixture.id)])
    }

    @Test("presentEdit nav → 자식 생성 + sheet present")
    func navigate_presents_edit_child() async {
        let coord = MemberCoordinator(deps: StubDeps(), memberID: MemberID("1"))
        let store = coord.makeMemberStore()

        store.send(.tapEdit)           // → navigate(.presentEdit)

        await waitUntil { coord.sheet != nil }
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
