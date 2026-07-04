import UIKit
import MapUI

/// SwiftUI App lifecycle 에 `@UIApplicationDelegateAdaptor` 로 부속 연결되는 AppDelegate.
/// 앱 수준 진입 훅(초기화, scene 구성)을 담당한다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // GoogleMaps SDK 초기화. 키는 Info.plist(GMSApiKey ← 빌드 세팅)에서 읽는다.
        // 미발급이면 빈 문자열 → configure 가 no-op(지도 회색, 크래시 없음).
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
        MapService.configure(apiKey: apiKey)
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
