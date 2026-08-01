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
                .navigationTitle("프로필 설정")
                .navigationBarTitleDisplayMode(.inline)
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
            ProfileSetupContent(
                name: Binding(
                    get: { store.state.name },
                    set: { store.send(.nameChanged($0)) }
                ),
                selectedCharacterIndex: store.state.selectedCharacterIndex,
                isSaveEnabled: store.state.isSaveEnabled,
                onSelectCharacter: { store.send(.selectCharacter($0)) },
                onClear: { store.send(.tapClear) },
                onSave: { store.send(.tapNext) }
            )
        } else {
            ProgressView()
                .task { store = coordinator.makeProfileSetupStore() }
        }
    }
}
