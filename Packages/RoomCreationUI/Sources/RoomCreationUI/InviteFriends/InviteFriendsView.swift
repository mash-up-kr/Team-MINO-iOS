import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
// Coordinator 대신 `makeStore` 클로저를 받는 이유는 RoomFormView 주석 참조.
public struct InviteFriendsView: View {
    private let makeStore: @MainActor () -> InviteFriendsStore
    private let showsSkip: Bool
    @State private var store: InviteFriendsStore?
    // 뒤로가기는 Coordinator 를 직접 쓰지 않고 dismiss 환경값으로 pop 한다 — NavigationStack push 화면에도 동작한다.
    @Environment(\.dismiss) private var dismiss

    /// - Parameter showsSkip: 상단바 건너뛰기 버튼 노출. 건너뛸 수 없는 진입점은 `false`.
    public init(makeStore: @escaping @MainActor () -> InviteFriendsStore, showsSkip: Bool = true) {
        self.makeStore = makeStore
        self.showsSkip = showsSkip
    }

    public var body: some View {
        Group {
            if let store {
                InviteFriendsContent(
                    onTapBack: { dismiss() },
                    onTapSkip: showsSkip ? { store.send(.tapComplete) } : nil,
                    onTapInvite: { store.send(.tapInvite) },
                    onTapCopyLink: { store.send(.tapCopyLink) }
                )
            } else {
                ProgressView()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }
}
