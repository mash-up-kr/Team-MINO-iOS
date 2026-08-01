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

/// 앱 루트 View. 최상위 Coordinator 의 자식 flow 를 화면에 연결한다.
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        MainTabView(coordinator: coordinator)
    }
}
