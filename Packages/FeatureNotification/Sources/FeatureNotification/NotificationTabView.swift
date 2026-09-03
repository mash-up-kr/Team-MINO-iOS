import DesignSystem
import FlowCoordination
import SwiftUI

/// 알림 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
/// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `XxxHomeView` 템플릿, ``HomeTabView`` 선례.
public struct NotificationTabView: View {
    private let coordinator: NotificationCoordinator
    @State private var store: NotificationListStore?

    public init(coordinator: NotificationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        // 바인딩은 스택 쪽에서만 필요하다 — 여기서 @Bindable 을 또 만들면 쓰지 않는 사본이 생긴다.
        ZStack(alignment: .bottom) {
            stack
            openFailureToast
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.openFailureToken)
    }

    private var stack: some View {
        @Bindable var coordinator = coordinator
        return NavigationStack(path: $coordinator.path) {
            content
                // 이 화면이 직접 헤더(NotificationListHeader)를 그린다 — 시스템 내비바를 숨긴다.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: NotificationRoute.self) { route in
                    switch route {
                    case .saveError:
                        NotificationSaveErrorContentView(onTapBack: { coordinator.pop() })
                            // 이 화면도 자체 상단바(MHTopNavigation)를 그린다 — 시스템 내비바를
                            // 숨기지 않으면 뒤로가기 버튼이 두 개 겹친다. 내비바를 숨기면 SwiftUI 가
                            // 엣지 백스와이프도 함께 꺼서(interactivePopGestureRecognizer 비활성화)
                            // enablesBackSwipe() 로 되살린다(``HomeTabView`` 의 CreateRoomView 선례).
                            .toolbar(.hidden, for: .navigationBar)
                            .enablesBackSwipe()
                    }
                }
        }
    }

    /// 이동 대상 조회에 실패했을 때. `NavigationStack` **바깥**에 둔다 — 안에 두면 탭바에 가린다
    /// (``HomeTabView/savedToast`` 선례).
    @ViewBuilder
    private var openFailureToast: some View {
        if let store, store.state.openFailureToken > 0 {
            let token = store.state.openFailureToken
            MHSnackbar(title: "화면을 열지 못했어요", icon: .circleExclamationFill)
                .padding(.horizontal, 20)
                // 011-2 스펙의 "스크린 하단에서 40" 을 탭바 위로 올린 값 — 알림 탭은 탭바가 살아 있다.
                .padding(.bottom, 40)
                .allowsHitTesting(false)
                .transition(.opacity)
                .accessibilityIdentifier("Notification.openFailureToast")
                .task(id: token) {
                    // 취소를 삼키면 안 된다. try? 로 받으면 새 스낵바가 이 task 를 취소했을 때
                    // sleep 이 즉시 반환하고, 이어지는 dismiss 가 **방금 뜬 것**을 지운다.
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    store.send(.dismissOpenFailureToast(token))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            NotificationListContainerView(store: store)
                .safeAreaInset(edge: .bottom, spacing: 0) { tabBarSpacer }
        } else {
            ProgressView()
                .task { store = coordinator.makeNotificationListStore() }
        }
    }

    /// `NavigationStack` 은 상위(`MainTabView`)의 `safeAreaInset` 탭바 인셋을 자기 콘텐츠에 전파하지
    /// 않고 기기 홈 인디케이터 인셋만 적용한다(``HomeTabView`` 주석). 그래서 스택 안의 목록
    /// `ScrollView` 는 탭바 아래까지 늘어나 마지막 셀이 가려진다 — 탭바 높이만큼을 여기서 직접
    /// 바닥 safe area 로 되돌려 준다.
    ///
    /// 홈처럼 플로팅 요소를 스택 바깥으로 빼는 방법은 여기 쓸 수 없다. 가려지는 게 특정 요소가
    /// 아니라 스크롤 콘텐츠 자체라, 스크롤 영역의 safe area 를 고쳐야 한다.
    ///
    /// `pop` 대상인 저장 오류 화면에는 붙이지 않는다 — 스크롤이 없어 가려질 콘텐츠가 없다.
    private var tabBarSpacer: some View {
        Color.clear.frame(height: MHTabBar.height)
    }
}
