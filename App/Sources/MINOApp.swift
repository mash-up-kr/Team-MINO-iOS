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
            // .onOpenURL { url in app.handle(url) }   // 딥링크 진입점 자리 (후속)
        }
    }
}

/// 앱 루트 View. 세션과 온보딩 완료 여부로 진입을 가른다.
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        // `.task` 를 아래 스위치에 직접 붙이면 phase 가 바뀔 때마다 뷰 identity 가 달라져
        // 재실행된다. 수명이 고정된 컨테이너에 붙여 1회를 보장한다
        // (reduce 의 `didStart` 가 2차 방어).
        ZStack {
            content
        }
        .task { coordinator.launch.send(.start) }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.launch.state.phase {
        case .loading:
            LaunchSplashView()
        case .retry:
            LaunchSplashView(failure: .init(
                message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요",
                onRetry: { coordinator.launch.send(.tapRetry) }
            ))
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
