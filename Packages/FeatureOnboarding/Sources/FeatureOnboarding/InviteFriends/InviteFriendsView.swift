import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
struct InviteFriendsView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: InviteFriendsStore?

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        // TODO [AI_IMPL]: store 있으면 placeholder 본문 — 화면명 Text·"완료" 버튼(store.send(.tapComplete)),
        //   accessibilityIdentifier "Onboarding.inviteFriends.complete"
        //   없으면 ProgressView().task { store = coordinator.makeInviteFriendsStore() }
        fatalError("not implemented")
    }
}
