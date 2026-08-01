import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 진입 화면 View가 NavigationStack 보유, Coordinator는 생성자 주입
public struct ProfileSetupView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: ProfileSetupStore?

    public init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            content
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .createRoom:
                        CreateRoomView(coordinator: coordinator)
                    case .inviteFriends:
                        InviteFriendsView(coordinator: coordinator)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            VStack(spacing: 16) {
                Text("프로필 설정")
                Button("다음") { store.send(.tapNext) }
                    .accessibilityIdentifier("Onboarding.profileSetup.next")
            }
        } else {
            ProgressView()
                .task { store = coordinator.makeProfileSetupStore() }
        }
    }
}
