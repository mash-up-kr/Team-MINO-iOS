import DesignSystem
import ProfileSetupUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `XxxHomeView` 템플릿, ``NotificationTabView`` 선례.
/// 마이 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator
    @State private var store: ProfileMainStore?
    @Environment(\.scenePhase) private var scenePhase

    public init(coordinator: ProfileCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            content
                // 이 화면은 상단 내비바가 없다(디자인 008-1) — 시스템 내비바를 숨긴다.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ProfileRoute.self) { route in
                    switch route {
                    case .profileSetup:
                        // 뒤로가기는 `onBack` 을 넘긴 쪽만 그려진다 — 온보딩 최초 진입과 달리
                        // 여기는 돌아갈 곳이 있다(`ProfileSetupScreen` 주석).
                        ProfileSetupScreen(
                            makeStore: { coordinator.makeProfileSetupStore() },
                            onBack: { coordinator.pop() }
                        )
                        // 내비바를 숨기면 SwiftUI 가 엣지 백스와이프도 함께 꺼서 되살린다(``NotificationTabView`` 선례).
                        .enablesBackSwipe()
                    }
                }
        }
        // 진입·복귀 시점마다 다시 읽는다(FR-009). 세 경로가 모두 "복귀" 다 —
        // 프로필 설정에서 pop, OS 설정 앱에서 복귀, 그리고 최초 진입(.task).
        .onChange(of: coordinator.path.isEmpty) { _, isRoot in
            if isRoot { refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    @ViewBuilder private var content: some View {
        if let store {
            ProfileMainContentView(state: store.state, send: store.send)
                .safeAreaInset(edge: .bottom, spacing: 0) { tabBarSpacer }
        } else {
            ProgressView()
                .task {
                    store = coordinator.makeProfileMainStore()
                    refresh()
                }
        }
    }

    /// 프로필과 스위치를 **따로** 보낸다 — 묶으면 즉시 읽히는 권한 상태가 네트워크 왕복을 기다린다.
    private func refresh() {
        guard let store else { return }
        store.send(.loadProfile)
        store.send(.syncSwitches)
    }

    /// `NavigationStack` 은 상위(`MainTabView`)의 `safeAreaInset` 탭바 인셋을 자기 콘텐츠에 전파하지
    /// 않고 기기 홈 인디케이터 인셋만 적용한다 — 탭바 높이만큼을 여기서 직접 되돌려 준다
    /// (``NotificationTabView.tabBarSpacer`` 와 같은 이유).
    private var tabBarSpacer: some View {
        Color.clear.frame(height: MHTabBar.height)
    }
}
