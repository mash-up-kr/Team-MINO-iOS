import Foundation

/// 기기의 푸시 토큰을 서버와 맞춘다. **알림이 켜져 있을 때만 올린다.**
public protocol SyncPushTokenUseCase: Sendable {
    /// 지금 토큰을 조회해 올린다. 앱 진입·포그라운드 복귀·스위치 ON 이 부른다.
    func execute() async
    /// SDK 가 새 토큰을 통보했을 때. 같은 게이트·같은 중복 제거를 지난다.
    func execute(token: String) async
}

/// 중복 제거 상태를 들어야 해 actor 다. 값 타입으로 두면 "이미 올린 토큰" 을 기억할 자리가 없어
/// 포그라운드로 돌아올 때마다 같은 PUT 이 나간다.
public actor DefaultSyncPushTokenUseCase: SyncPushTokenUseCase {
    private let permissions: PermissionRepository
    private let settings: AppSettingsRepository
    private let registration: PushRegistrationRepository
    private let provider: PushTokenProvider
    private let repository: PushTokenRepository

    /// **프로세스 수명만 기억한다.** 영구 저장하지 않는 이유: 서버 쪽에서 행이 사라지거나 익명 uid 가
    /// 바뀌어도 앱을 다시 켜면 한 번은 반드시 올라가게 두기 위해서다.
    private var lastUploaded: String?

    /// 이 프로세스에서 APNs 등록을 이미 요청했는가.
    ///
    /// **없으면 무한 루프가 된다.** 등록은 캐시된 토큰으로 곧바로 도착 콜백을 부르고, 그 콜백이
    /// 다시 이 UseCase 를 두드리기 때문이다(`AppDelegate.didRegisterForRemoteNotifications…`).
    /// 프로세스당 한 번이면 충분하다는 것도 Apple 의 권장과 같다.
    private var didRequestRegistration = false

    public init(
        permissions: PermissionRepository,
        settings: AppSettingsRepository,
        registration: PushRegistrationRepository,
        provider: PushTokenProvider,
        repository: PushTokenRepository
    ) {
        self.permissions = permissions
        self.settings = settings
        self.registration = registration
        self.provider = provider
        self.repository = repository
    }

    public func execute() async {
        guard await isNotificationDeliveryOn(permissions, settings) else { return }
        // **APNs 등록을 먼저 요청한다.** 등록은 프로세스마다 필요한데(시스템은 캐시된 토큰을 곧바로
        // 돌려준다) 스위치를 켜는 순간에만 부르면 다음 콜드런치에는 APNs 토큰이 없다. 그러면 FCM 이
        // 토큰 발급을 거부해(`No APNS token specified`) 올릴 것이 없어지고, 알림함에는 쌓이는데
        // 푸시만 오지 않는다 — 실제로 재현했다.
        if !didRequestRegistration {
            didRequestRegistration = true
            await registration.register()
        }
        // 게이트를 통과한 뒤에만 묻는다 — 조회 자체가 토큰을 만들어 내는 호출이라, 켠 적 없는
        // 사용자에게 토큰이 발급되는 걸 이 순서가 막는다(`FCMPushTokenProvider` 주석).
        guard let token = await provider.currentToken() else { return }
        await upload(token)
    }

    /// SDK 가 토큰을 통보했다는 건 APNs 토큰이 이미 도착했다는 뜻이라, 이 경로는 등록을 다시
    /// 요청하지 않는다.
    public func execute(token: String) async {
        guard await isNotificationDeliveryOn(permissions, settings) else { return }
        await upload(token)
    }

    private func upload(_ token: String) async {
        guard !token.isEmpty, token != lastUploaded else { return }   // 서버 계약이 minLength 1 이다

        // **요청을 보내기 전에 표시한다.** actor 는 `await` 에서 재진입하므로, 성공한 뒤에 쓰면
        // 겹쳐 들어온 두 번째 호출이 같은 가드를 통과해 같은 토큰을 한 번 더 올린다 — 콜드런치에서
        // `execute()`(앱 진입)와 `execute(token:)`(SDK 갱신 통보)이 같은 값으로 함께 오는 조합이 있다.
        lastUploaded = token
        do {
            try await repository.register(token: token)
        } catch {
            // 재시도 타이머를 두지 않는다 — 부르는 계기(앱 진입·포그라운드 복귀·토큰 갱신)가 이미
            // 충분히 자주 온다. 실패를 기억하지 않으므로 다음 계기에 그대로 다시 시도된다.
            lastUploaded = nil
        }
    }
}
