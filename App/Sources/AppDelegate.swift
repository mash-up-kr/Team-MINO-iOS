import FirebaseMessaging
import Logging
import MapUI
import UIKit

/// SwiftUI App lifecycle 에 `@UIApplicationDelegateAdaptor` 로 부속 연결되는 AppDelegate.
/// 앱 수준 진입 훅(초기화, scene 구성)을 담당한다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 푸시 수신·탭 채널. **프로세스 시작에 붙어야 한다** — 콜드런치에서 알림을 눌러 앱이 켜지면
    /// `didReceive` 가 launch 직후 한 번 오고, 그때 delegate 가 비어 있으면 그 탭은 사라진다.
    let pushRouter = PushRouter()
    /// FCM 토큰 채널. 소비자(`PushTokenSync`)는 앱 그래프가 생긴 뒤 `connect(_:)` 로 꽂는다 —
    /// 그 전에 온 첫 토큰은 이 객체가 들고 있다.
    let pushTokenObserver = PushTokenObserver()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 초기화 + 세션 Keychain 그룹 지정. 익스텐션도 같은 함수를 부른다.
        FirebaseSession.configure()

        // `Messaging` 을 만지기 전에 `FirebaseApp.configure()` 가 끝나 있어야 한다 — 위 호출이
        // 그 순서를 보장하는 자리다.
        Messaging.messaging().delegate = pushTokenObserver
        UNUserNotificationCenter.current().delegate = pushRouter

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

    /// 푸시 채널의 소비자를 꽂는다. delegate 자체는 이미 프로세스 시작에 붙어 있고, 여기서 잇는 건
    /// **앱 그래프를 아는 쪽**뿐이다(`AppCoordinator` 는 SwiftUI 쪽에서 만들어져 시점이 다르다).
    /// 그 사이 도착한 토큰·탭은 각 어댑터가 들고 있다가 이 순간 흘러나온다.
    @MainActor
    func connect(_ app: AppCoordinator) {
        pushRouter.route.onValue = { [weak app] route in app?.handle(push: route) }
        pushTokenObserver.token.onValue = { [weak app] token in app?.pushTokenSync.tokenDidRefresh(token) }
    }

    /// APNs 등록 실패는 조용하다 — 이 로그가 없으면 "토큰이 안 온다"는 사실만 남는다.
    /// 엔타이틀먼트 누락·프로비저닝 불일치·Developer Portal 의 Push 미활성이 전부 여기로 떨어진다.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.warning("APNs 등록 실패", metadata: ["reason": String(describing: error)])
    }

    // `didRegisterForRemoteNotificationsWithDeviceToken` 은 두지 않는다 — Firebase 스위즐링
    // (`FirebaseAppDelegateProxyEnabled` 미설정 = 켜짐)이 이걸 가로채 `Messaging.apnsToken` 을
    // 대신 채운다. 끄고 손으로 대입하는 걸 빠뜨리면 FCM 토큰은 정상 발급되는데 발송만 조용히
    // 실패한다 — 코드·빌드·테스트 어디에도 흔적이 안 남는 실패다.
}
