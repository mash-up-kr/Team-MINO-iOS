import DesignSystem
import ProfileSetupUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `XxxHomeView` 템플릿, ``NotificationTabView`` 선례.
/// 마이 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator
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
        // 진입·복귀 시점마다 다시 읽는다. 세 경로가 모두 "복귀" 다 —
        // 프로필 설정에서 pop, OS 설정 앱에서 복귀, 그리고 탭 진입(.task).
        //
        // **스위치와 프로필은 근거가 다르다.** 스위치 재동기화는 스펙 요구(FR-009 — "로컬 캐시가
        // 아니라 진입·복귀 시점마다 재조회")이고, 프로필 재조회는 스펙에 없는 구현 선택이다
        // (스펙이 프로필에 요구하는 건 FR-003 "저장 완료 시 즉시 반영" 뿐이다).
        // 다른 기기·다른 경로에서 바뀐 값을 따라잡으려고 같은 시점에 함께 보낸다.
        .onChange(of: coordinator.path.isEmpty) { _, isRoot in
            if isRoot { refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    // 로딩 자리표시자(스피너)를 두지 않는다. Store 가 Coordinator 에 살아 있어 **첫 프레임부터**
    // 마지막으로 알던 프로필로 화면을 채울 수 있고, 재조회는 그 위에서 조용히 끝난다.
    // 스피너를 한 프레임이라도 끼우면 그게 곧 "빈 화면 → 값" 바꿔치기로 보인다.
    private var content: some View {
        let store = coordinator.profileMainStore()
        return ProfileMainContentView(state: store.state, send: store.send)
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBarSpacer }
            // 탭에 들어올 때마다 다시 읽는다. 탭을 떠나면 이 View 는 폐기되므로
            // (`MainTabView` 는 선택된 탭만 그린다) 재진입마다 한 번씩 돈다.
            // 스위치에는 이 재조회가 스펙 요구다(FR-009) — 위 `onChange` 주석 참조.
            .task { refresh() }
    }

    /// 프로필과 스위치를 **따로** 보낸다 — 묶으면 즉시 읽히는 권한 상태가 네트워크 왕복을 기다린다.
    private func refresh() {
        let store = coordinator.profileMainStore()
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
