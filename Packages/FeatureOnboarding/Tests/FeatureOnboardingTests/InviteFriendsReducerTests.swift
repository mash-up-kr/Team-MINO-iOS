import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct InviteFriendsReducerTests {
    @Test("L2 — 건너뛰기(tapComplete) 는 complete 로 navigate 한다")
    func tapComplete_navigatesToComplete() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapComplete)
        store.receiveNavigation(.complete)

        store.finish()
    }

    @Test("L1 — 뒤로가기(tapBack) 는 state 를 바꾸지 않고 navigate 하지도 않는다 (실제 pop 은 View 의 dismiss 가 담당)")
    func tapBack_doesNotMutateStateOrNavigate() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapBack)

        store.finish()
    }

    @Test("L1 — 친구 초대하기(tapInvite) 는 미연결 동작이라 state 를 바꾸지 않는다")
    func tapInvite_doesNothing() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapInvite)

        store.finish()
    }

    @Test("L1 — 초대 링크 복사(tapCopyLink) 는 미연결 동작이라 state 를 바꾸지 않는다")
    func tapCopyLink_doesNothing() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapCopyLink)

        store.finish()
    }
}
