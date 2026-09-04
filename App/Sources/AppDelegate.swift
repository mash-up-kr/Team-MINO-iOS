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

        // 로그 백엔드 조립(Composition Root). 개발은 전부, 릴리즈는 info↑만 남긴다.
        //
        // ⚠️ 릴리즈 기준을 **UT 기간 한정으로** warning → info 로 낮춰 둔 상태다. 푸시 경로가
        // 실패해도 흔적을 남기지 않아 TestFlight 빌드로는 판정이 불가능했다. 원인이 잡히면
        // warning 으로 되돌린다. 요청·응답 본문을 찍는 `NetworkLogger` 는 debug 라 여전히 꺼져 있다.
        #if DEBUG
        Log.bootstrap(OSLogger(minimumLevel: .debug))
        #else
        Log.bootstrap(OSLogger(minimumLevel: .info))
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

    /// APNs 토큰이 도착했을 때 토큰 업로드를 다시 두드린다. `connect(_:)` 가 꽂는다.
    ///
    /// 옆의 두 채널과 달리 `PendingHandoff` 를 쓰지 않는다 — 그건 **값을** 전달하는 도구인데 여기엔
    /// 전달할 값이 없다. 늦게 꽂혀 신호를 놓칠 일도 없다: 도착 콜백은 `registerForRemoteNotifications()`
    /// 뒤에만 오고, 그 호출은 `SyncPushTokenUseCase.execute()` 안에 있어 앱 그래프가 생긴
    /// 뒤(= `connect(_:)` 이후)에야 나간다.
    private var apnsTokenDidArrive: (@MainActor () -> Void)?

    /// 푸시 채널의 소비자를 꽂는다. delegate 자체는 이미 프로세스 시작에 붙어 있고, 여기서 잇는 건
    /// **앱 그래프를 아는 쪽**뿐이다(`AppCoordinator` 는 SwiftUI 쪽에서 만들어져 시점이 다르다).
    /// 그 사이 도착한 토큰·탭은 각 어댑터가 들고 있다가 이 순간 흘러나온다.
    @MainActor
    func connect(_ app: AppCoordinator) {
        pushRouter.route.onValue = { [weak app] route in app?.handle(push: route) }
        pushTokenObserver.token.onValue = { [weak app] token in app?.pushTokenSync.tokenDidRefresh(token) }
        apnsTokenDidArrive = { [weak app] in app?.pushTokenSync.kick() }
    }

    /// APNs 등록 실패는 조용하다 — 이 로그가 없으면 "토큰이 안 온다"는 사실만 남는다.
    /// 엔타이틀먼트 누락·프로비저닝 불일치·Developer Portal 의 Push 미활성이 전부 여기로 떨어진다.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.warning("APNs 등록 실패", metadata: ["reason": String(describing: error)])
    }

    /// APNs 토큰 도착. **`Messaging.apnsToken` 을 채우는 유일한 경로다.**
    ///
    /// `Info.plist` 에서 `FirebaseAppDelegateProxyEnabled` 를 껐기 때문에 SDK 가 대신 채워 주지
    /// 않는다(끈 이유는 그 키의 주석 참조 — 켜 두면 이 콜백을 가로챈 뒤 우리 구현으로 넘기지도,
    /// 자기 쪽 대입을 하지도 않았다). 이 메서드를 지우면 FCM 이 토큰 발급을 거부하고
    /// (`No APNS token specified`) **아무 에러 없이 푸시만 안 온다.**
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken

        // [진단] 이 경로는 실패해도 아무 흔적이 없어 관측 없이는 판정이 안 된다 —
        // "콜백이 안 온 것"과 "대입이 먹지 않은 것"이 밖에서 똑같아 보인다.
        // 토큰 값 자체는 찍지 않는다(길이만). `applied`·`autoInit` 은 원인이 잡히면 걷어낸다.
        Log.info("APNs 토큰 수신", metadata: [
            "bytes": String(deviceToken.count),
            "applied": String(Messaging.messaging().apnsToken != nil),
            "autoInit": String(Messaging.messaging().isAutoInitEnabled)
        ])

        // FCM 토큰을 **처음으로 받을 수 있게 된** 시점이다. 여기서 두드리지 않으면 다음 앱 진입까지
        // 서버에 토큰이 없다.
        apnsTokenDidArrive?()
    }
}
