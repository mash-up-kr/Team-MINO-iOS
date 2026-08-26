import RoomCreationUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 진입 화면 View가 NavigationStack 보유, Coordinator는 생성자 주입
public struct ProfileSetupView: View {
    private let coordinator: OnboardingCoordinator
    private let showsBack: Bool
    @State private var store: ProfileSetupStore?
    @Environment(\.dismiss) private var dismiss

    /// - Parameter showsBack: 상단바 뒤로가기 노출. 돌아갈 곳이 없는 진입점(온보딩 최초 진입)은 `false`.
    ///   마이페이지처럼 앞 화면이 있는 진입점에서 `true` 로 준다.
    public init(coordinator: OnboardingCoordinator, showsBack: Bool = false) {
        self.coordinator = coordinator
        self.showsBack = showsBack
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            content
                // 마크업이 자체 상단 내비바를 그린다 — 세 화면이 같은 MHTopNavigation 을 쓴다.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .createRoom:
                        // 온보딩엔 돌아갈 곳이 없어 뒤로가기를 숨긴다(디자인 ⑦). 대신 건너뛰기가 있다(⑥).
                        RoomFormView(makeStore: coordinator.makeRoomFormStore, showsBack: false)
                    case .inviteFriends:
                        InviteFriendsView(makeStore: coordinator.makeInviteFriendsStore)
                    case .tutorial:
                        TutorialView(makeStore: coordinator.makeTutorialStore)
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
                showsNameError: store.state.shouldShowNameError,
                isSaveEnabled: store.state.isSaveEnabled,
                isClearEnabled: store.state.isClearEnabled,
                onSelectCharacter: { store.send(.selectCharacter($0)) },
                onClear: { store.send(.tapClear) },
                onSave: { store.send(.tapSave) },
                // 뒤로가기는 state 를 바꾸지 않아 Action 을 두지 않는다(InviteFriendsStore 와 같은 판단).
                onBack: showsBack ? { dismiss() } : nil
            )
        } else {
            ProgressView()
                .task { store = coordinator.makeProfileSetupStore() }
        }
    }
}
