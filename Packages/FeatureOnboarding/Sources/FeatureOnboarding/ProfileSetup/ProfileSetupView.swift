import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 진입 화면 View가 NavigationStack 보유, Coordinator는 생성자 주입
public struct ProfileSetupView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: ProfileSetupStore?

    public init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        // TODO [AI_IMPL]: NavigationStack(path: $coordinator.path)
        //   + navigationDestination(for: OnboardingRoute.self) → CreateRoomView / InviteFriendsView (coordinator 주입)
        //   + placeholder 본문: 화면명 Text·"다음" 버튼(store.send(.tapNext)), accessibilityIdentifier "Onboarding.profileSetup.next"
        //   + store 지연 생성: .task { store = coordinator.makeProfileSetupStore() }
        fatalError("not implemented")
    }
}
