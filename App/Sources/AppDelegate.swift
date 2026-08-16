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
        // 로그 백엔드 조립(Composition Root). 개발은 전부, 릴리즈는 warning↑만 남긴다.
        #if DEBUG
        Log.bootstrap(OSLogger(minimumLevel: .debug))
        #else
        Log.bootstrap(OSLogger(minimumLevel: .warning))
        #endif

        // GoogleMaps SDK 초기화. 키는 Info.plist(GMSApiKey ← 빌드 세팅 GOOGLE_MAPS_API_KEY)에서 읽는다.
        // 미발급이면 빈 문자열 → configure 미실행, 지도 자리에 플레이스홀더 표시(크래시 없음).
        let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
        MapService.configure(apiKey: mapsAPIKey)

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
