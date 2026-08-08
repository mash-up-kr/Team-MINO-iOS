import MVITestSupport
import Testing
@testable import RoomCreationUI

@MainActor
struct InviteFriendsReducerTests {
    // 종료 조건이 기획에 없어 건너뛰기를 비워둔 상태다. `.navigate(.complete)` 를 되살릴 때는
    // 이 테스트와 OnboardingCoordinatorTests 의 InviteFriends 배선 테스트를 함께 되돌린다.
    @Test("L1 — 건너뛰기(tapComplete) 는 아직 navigate 하지 않는다")
    func tapComplete_doesNotNavigate() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapComplete)

        store.finish()   // 미수신 nav 가 있으면 여기서 실패한다
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
