import FirebaseCore
import Logging
import MapUI
import UIKit

/// SwiftUI App lifecycle 에 `@UIApplicationDelegateAdaptor` 로 부속 연결되는 AppDelegate.
/// 앱 수준 진입 훅(초기화, scene 구성)을 담당한다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Crashlytics 가 초기화 이후의 크래시만 잡으므로 가장 먼저 부른다.
        FirebaseApp.configure()

        // 로그 백엔드 조립(Composition Root). 개발은 전부, 릴리즈는 warning↑만 남긴다.
        #if DEBUG
        Log.bootstrap(OSLogger(minimumLevel: .debug))
        #else
        Log.bootstrap(OSLogger(minimumLevel: .warning))
        #endif

        MapService.configure(apiKey: Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? "")

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
