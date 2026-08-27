import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
// Coordinator 대신 `makeStore` 클로저를 받는 이유는 RoomFormView 주석 참조.
public struct InviteFriendsView: View {
    private let makeStore: @MainActor () -> InviteFriendsStore
    private let showsClose: Bool
    @State private var store: InviteFriendsStore?

    /// - Parameter showsClose: 상단바 닫기(X) 버튼 노출. 닫을 수 없는 진입점은 `false`.
    public init(makeStore: @escaping @MainActor () -> InviteFriendsStore, showsClose: Bool = true) {
        self.makeStore = makeStore
        self.showsClose = showsClose
    }

    public var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                ProgressView()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }

    private func content(_ store: InviteFriendsStore) -> some View {
        InviteFriendsContent(
            onTapClose: showsClose ? { store.send(.tapComplete) } : nil,
            isInviteEnabled: store.state.isInviteEnabled,
            notice: store.state.notice,
            onTapInvite: { store.send(.tapInvite) },
            onTapCopyLink: { store.send(.tapCopyLink) }
        )
        .sheet(item: sharingLink(store)) { ShareSheet(url: $0.url) }
        // 안내는 잠깐 띄웠다 거둔다. id 를 걸어 새 안내가 오면 타이머가 다시 시작된다.
        .task(id: store.state.notice) {
            guard store.state.notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            store.send(.dismissNotice)
        }
    }

    /// 시트는 사용자가 스와이프로도 닫으므로 닫힘을 Store 에 되돌려준다 — 안 그러면 링크가 state 에
    /// 남아 시트가 다시 뜬다.
    private func sharingLink(_ store: InviteFriendsStore) -> Binding<SharedInviteLink?> {
        Binding(
            get: { store.state.sharingLink },
            set: { if $0 == nil { store.send(.dismissShareSheet) } }
        )
    }
}
