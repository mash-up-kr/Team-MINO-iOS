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
                .task {
                    // 푸시 delegate 는 프로세스 시작에 이미 붙어 있고 여기서는 **소비자만** 꽂는다.
                    // (`@UIApplicationDelegateAdaptor` 프로퍼티는 body 안에서 읽는다 — init 에선 이르다)
                    appDelegate.connect(app)
                    app.launch.send(.start)
                }
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let launch = coordinator.launch.state
        Group {
            switch launch.phase {
            // 실패도 이 구간이다 — 스낵바를 얹은 채 자동 재시도가 돈다(시안 012-2/3/4).
            case .idle, .loading:
                LaunchSplashView(isSlow: launch.isSlow, notice: launch.notice)
            case .onboarding:
                OnboardingHost(coordinator: coordinator)
            case .main:
                // 탭이 실제로 뜬 시점 — 보류된 푸시를 소비하고 토큰 업로드를 두드린다.
                // `.main` 안에서는 identity 가 고정이라 1회만 실행된다.
                MainTabView(coordinator: coordinator)
                    .task { coordinator.mainDidAppear() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.didBecomeActive() }
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
