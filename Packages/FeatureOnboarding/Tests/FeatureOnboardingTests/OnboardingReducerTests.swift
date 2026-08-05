import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingReducerTests {
    @Test("L2 — profileSetupReducer: tapNext 는 goToCreateRoom 으로 navigate 한다")
    func profileSetup_tapNext_navigates() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.tapNext)
        store.receiveNavigation(.goToCreateRoom)

        store.finish()
    }

    @Test("L2 — createRoomReducer: tapNext 는 goToInviteFriends 로 navigate 한다")
    func createRoom_tapNext_navigates() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.tapNext)
        store.receiveNavigation(.goToInviteFriends)

        store.finish()
    }

    @Test("L1 — inviteFriendsReducer: tapComplete 는 아직 navigate 하지 않는다")
    func inviteFriends_tapComplete_doesNotNavigate() async {
        let store = TestStore(InviteFriendsState(), reduce: inviteFriendsReducer())

        await store.send(.tapComplete)

        store.finish()
    }
}
