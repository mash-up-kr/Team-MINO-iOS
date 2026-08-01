import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingReducerTests {
    // TODO [AI_IMPL]: profileSetupReducer — send(.tapNext) → receiveNavigation(.goToCreateRoom), 끝에 finish()
    // TODO [AI_IMPL]: createRoomReducer — send(.tapNext) → receiveNavigation(.goToInviteFriends), 끝에 finish()
    // TODO [AI_IMPL]: inviteFriendsReducer — send(.tapComplete) → receiveNavigation(.complete), 끝에 finish()
}
