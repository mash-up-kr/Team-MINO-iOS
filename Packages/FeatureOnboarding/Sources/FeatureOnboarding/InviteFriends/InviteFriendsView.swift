import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
struct InviteFriendsView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: InviteFriendsStore?
    // 뒤로가기는 Coordinator 를 직접 쓰지 않고 dismiss 환경값으로 pop 한다 — NavigationStack push 화면에도 동작한다.
    @Environment(\.dismiss) private var dismiss

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        Group {
            if let store {
                InviteFriendsContent(
                    onTapBack: {
                        store.send(.tapBack)
                        dismiss()
                    },
                    onTapSkip: { store.send(.tapComplete) },
                    onTapInvite: { store.send(.tapInvite) },
                    onTapCopyLink: { store.send(.tapCopyLink) }
                )
            } else {
                ProgressView()
                    .task { store = coordinator.makeInviteFriendsStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }
}
