import DesignSystem
import FeatureOnboarding
import SwiftUI

@main
struct MINOApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app: AppCoordinator

    init() {
        _app = State(initialValue: AppCoordinator(deps: AppDependencies()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: app)
                // RootView 는 WindowGroup 안에서 identity 가 고정이라 1회만 실행된다
                // (reduce 의 `.idle` 가드가 2차 방어).
                .task { app.launch.send(.start) }
                // 콜드 런치로 들어온 URL 도 SwiftUI 가 여기로 넘겨준다.
                // ⚠️ `SceneDelegate` 에 `scene(_:openURLContexts:)` 를 구현하면 이 modifier 가
                //    조용히 안 불린다 — SwiftUI 가 URL 전달을 그쪽에 넘기기 때문.
                .onOpenURL { url in app.handle(url) }
        }
    }
}

/// 앱 루트 View. 세션과 온보딩 완료 여부로 진입을 가른다.
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        content
            // 초대 안내는 phase 밖에 둔다 — 실패 시점이 스플래시일 수도 온보딩·메인일 수도 있어
            // 화면이 갈려도 살아남아야 한다(`AppLaunchState.notice` 는 스플래시에서만 그려진다).
            .overlay(alignment: .bottom) { inviteNotice }
            .animation(.easeInOut(duration: 0.2), value: coordinator.inviteNotice)
    }

    @ViewBuilder private var content: some View {
        let launch = coordinator.launch.state
        // 초대를 확인·합류하는 동안은 진입 화면을 유지한다(Flow 6 협의). 온보딩 경로가 그 결과에
        // 달려 있고, 합류 뒤 열 방이 정해지기 전에 탭을 보여주면 화면이 두 번 바뀐다.
        if coordinator.isResolvingInvite {
            LaunchSplashView(isSlow: true)
        } else {
            switch launch.phase {
            // 실패도 이 구간이다 — 스낵바를 얹은 채 자동 재시도가 돈다(시안 012-2/3/4).
            case .idle, .loading:
                LaunchSplashView(isSlow: launch.isSlow, notice: launch.notice)
            case .onboarding:
                OnboardingHost(coordinator: coordinator)
            case .main:
                MainTabView(coordinator: coordinator)
            }
        }
    }

    @ViewBuilder private var inviteNotice: some View {
        if let notice = coordinator.inviteNotice {
            MHSnackbar(title: Self.message(for: notice), icon: .circleExclamation)
                .accessibilityIdentifier("Invite.notice")
                .padding(.horizontal, 20)
                .padding(.bottom, noticeBottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// 스낵바를 화면 바닥에서 얼마나 띄울지.
    ///
    /// 탭바는 `MainTabView` 안에서 `safeAreaInset` 으로 붙어 이 오버레이의 바깥이라, 스플래시와
    /// 같은 값(40)을 쓰면 탭바를 덮는다. 메인일 때만 탭바 높이를 더해 그 **위 20pt** 에 세운다.
    private var noticeBottomInset: CGFloat {
        guard !coordinator.isResolvingInvite,
              coordinator.launch.state.phase == .main
        else { return 40 }   // 스플래시·온보딩 — 시안 012-3/4 와 같은 값
        return MHTabBar.height + 20
    }

    private static func message(for notice: InviteNotice) -> String {
        switch notice {
        case .expired:        "초대 링크가 만료되었어요."
        case .notAllowed:     "참여할 수 없는 방이에요."
        case .connectionLost: "연결이 불안정해요. 링크를 다시 눌러주세요."
        case .temporary:      "일시적인 오류가 발생했어요."
        }
    }
}

/// 온보딩 Coordinator 를 `.task` 에서 1회 만들어 넘긴다.
/// (`makeOnboarding()` 이 `@MainActor` 라 non-isolated 인 View.init 에서 부를 수 없다)
private struct OnboardingHost: View {
    let coordinator: AppCoordinator
    @State private var onboarding: OnboardingCoordinator?

    var body: some View {
        if let onboarding {
            ProfileSetupView(coordinator: onboarding)
        } else {
            // 직전 화면과 같은 스플래시라 이 한 프레임이 눈에 띄지 않는다.
            LaunchSplashView()
                .task { onboarding = coordinator.makeOnboarding() }
        }
    }
}
