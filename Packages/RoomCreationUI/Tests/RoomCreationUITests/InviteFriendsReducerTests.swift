import MVITestSupport
import Testing
@testable import RoomCreationUI

@MainActor
struct InviteFriendsReducerTests {
    @Test("L2 — 닫기(tapComplete) 는 complete 를 알린다 — 목적지는 받는 쪽이 정한다")
    func tapComplete_notifiesComplete() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapComplete)
        store.receiveNavigation(.complete)

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
