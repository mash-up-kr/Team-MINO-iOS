import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
struct InviteFriendsView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: InviteFriendsStore?

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        Group {
            if let store {
                VStack(spacing: 16) {
                    Text("친구초대")
                    Button("완료") { store.send(.tapComplete) }
                        .accessibilityIdentifier("Onboarding.inviteFriends.complete")
                }
            } else {
                ProgressView()
                    .task { store = coordinator.makeInviteFriendsStore() }
            }
        }
    }
}
