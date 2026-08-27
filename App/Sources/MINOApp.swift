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
            // .onOpenURL { url in app.handle(url) }   // 딥링크 진입점 자리 (후속)
        }
    }
}

/// 앱 루트 View. 세션과 온보딩 완료 여부로 진입을 가른다.
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        switch coordinator.launch.state.phase {
        case .idle, .loading:
            LaunchSplashView()
        case .retry:
            LaunchSplashView(onRetry: { coordinator.launch.send(.tapRetry) })
        case .onboarding:
            OnboardingHost(coordinator: coordinator)
        case .main:
            MainTabView(coordinator: coordinator)
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
