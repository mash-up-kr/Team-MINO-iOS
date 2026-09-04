import Testing
@testable import Domain

// MARK: - Test Doubles

/// 켜짐 판정에 쓰는 두 축만 흉내 낸다. 위치는 이 스위트와 무관해 미결정으로 둔다.
private final class StubPermissionRepository: PermissionRepository, @unchecked Sendable {
    let notification: PermissionStatus
    init(notification: PermissionStatus) { self.notification = notification }

    func notificationStatus() async -> PermissionStatus { notification }
    func requestNotification() async -> PermissionStatus { notification }
    func locationStatus() async -> PermissionStatus { .notDetermined }
    func requestLocation() async -> PermissionStatus { .notDetermined }
}

private final class InMemoryAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private var enabled: Bool
    init(enabled: Bool) { self.enabled = enabled }
    func isNotificationDeliveryEnabled() -> Bool { enabled }
    func setNotificationDeliveryEnabled(_ value: Bool) { enabled = value }
}

/// 토큰을 돌려주면서 **몇 번 물었는지** 센다 — 꺼져 있을 때 조회조차 하지 않는 것이 계약이다.
private actor SpyPushTokenProvider: PushTokenProvider {
    private let token: String?
    private(set) var callCount = 0
    init(token: String?) { self.token = token }

    func currentToken() async -> String? {
        callCount += 1
        return token
    }
}

private actor SpyPushTokenRepository: PushTokenRepository {
    private var failures: Int
    /// 요청이 도는 동안 다른 호출이 끼어들 틈을 만든다 — 재진입은 이 지연 없이는 재현되지 않는다.
    private let delay: Duration?
    private(set) var uploaded: [String] = []

    /// `failures` 번은 실패하고 그 뒤로 성공한다 — "실패 후 다음 계기에 재시도" 를 보려면 둘 다 필요하다.
    init(failures: Int = 0, delay: Duration? = nil) {
        self.failures = failures
        self.delay = delay
    }

    func register(token: String) async throws {
        if let delay { try? await Task.sleep(for: delay) }
        if failures > 0 {
            failures -= 1
            throw DomainError.unknown
        }
        uploaded.append(token)
    }
}

// MARK: -

struct SyncPushTokenUseCaseTests {
    private func make(
        notification: PermissionStatus = .granted,
        deliveryEnabled: Bool = true,
        provider: SpyPushTokenProvider = SpyPushTokenProvider(token: "fcm-token-1"),
        repository: SpyPushTokenRepository = SpyPushTokenRepository()
    ) -> DefaultSyncPushTokenUseCase {
        DefaultSyncPushTokenUseCase(
            permissions: StubPermissionRepository(notification: notification),
            settings: InMemoryAppSettingsRepository(enabled: deliveryEnabled),
            provider: provider,
            repository: repository
        )
    }

    // 조회 자체가 토큰을 발급시키는 호출이라, 켠 적 없는 사용자에게 토큰이 만들어지면 안 된다.
    @Test("OS 권한이 없으면 토큰을 조회조차 하지 않는다")
    func execute_whenPermissionDenied_doesNotEvenAsk() async {
        let provider = SpyPushTokenProvider(token: "fcm-token-1")
        let repository = SpyPushTokenRepository()

        await make(notification: .denied, provider: provider, repository: repository).execute()

        #expect(await provider.callCount == 0)
        #expect(await repository.uploaded.isEmpty)
    }

    // FR-014 — 권한은 살아 있어도 앱에서 껐으면 올리지 않는다. 스위치 표시값과 같은 규칙이다.
    @Test("권한만 있고 앱 발송 설정이 꺼져 있으면 올리지 않는다")
    func execute_whenDeliveryDisabled_doesNotUpload() async {
        let provider = SpyPushTokenProvider(token: "fcm-token-1")
        let repository = SpyPushTokenRepository()

        await make(deliveryEnabled: false, provider: provider, repository: repository).execute()

        #expect(await provider.callCount == 0)
        #expect(await repository.uploaded.isEmpty)
    }

    @Test("켜져 있으면 조회한 토큰을 올린다")
    func execute_whenOn_uploads() async {
        let repository = SpyPushTokenRepository()

        await make(repository: repository).execute()

        #expect(await repository.uploaded == ["fcm-token-1"])
    }

    // 포그라운드 복귀마다 같은 PUT 이 나가는 걸 막는다.
    @Test("같은 토큰은 두 번 올리지 않는다")
    func execute_twice_uploadsOnce() async {
        let repository = SpyPushTokenRepository()
        let sut = make(repository: repository)

        await sut.execute()
        await sut.execute()

        #expect(await repository.uploaded == ["fcm-token-1"])
    }

    // 실패를 기억하지 않는 것이 곧 재시도 정책이다 — 별도 타이머를 두지 않는 근거.
    @Test("업로드에 실패하면 다음 호출에서 다시 시도한다")
    func execute_afterFailure_retriesOnNextCall() async {
        let repository = SpyPushTokenRepository(failures: 1)
        let sut = make(repository: repository)

        await sut.execute()
        #expect(await repository.uploaded.isEmpty)

        await sut.execute()
        #expect(await repository.uploaded == ["fcm-token-1"])
    }

    // 서버 계약이 minLength 1 이라 빈 문자열은 400 을 받는다.
    @Test("빈 토큰은 보내지 않는다")
    func execute_withEmptyToken_doesNotUpload() async {
        let repository = SpyPushTokenRepository()

        await make(provider: SpyPushTokenProvider(token: ""), repository: repository).execute()

        #expect(await repository.uploaded.isEmpty)
    }

    @Test("토큰을 얻지 못하면 아무 일도 하지 않는다")
    func execute_withoutToken_doesNothing() async {
        let repository = SpyPushTokenRepository()

        await make(provider: SpyPushTokenProvider(token: nil), repository: repository).execute()

        #expect(await repository.uploaded.isEmpty)
    }

    // actor 는 `await` 에서 재진입한다 — 중복 제거 표시를 요청 뒤에 하면 이 시나리오가 두 번 올린다.
    // 콜드런치에서 앱 진입(`execute`)과 SDK 갱신 통보(`execute(token:)`)가 같은 토큰으로 겹치는 조합이다.
    @Test("겹쳐 들어온 두 호출이 같은 토큰을 두 번 올리지 않는다")
    func concurrentCalls_uploadOnce() async {
        let repository = SpyPushTokenRepository(delay: .milliseconds(50))
        let sut = make(repository: repository)

        async let first: Void = sut.execute()
        async let second: Void = sut.execute(token: "fcm-token-1")
        _ = await (first, second)

        #expect(await repository.uploaded == ["fcm-token-1"])
    }

    // SDK 갱신 콜백은 조회를 건너뛰지만 게이트는 똑같이 지나야 한다.
    @Test("갱신 콜백 경로도 같은 게이트와 중복 제거를 지난다")
    func executeWithToken_sharesGateAndDeduplication() async {
        let offRepository = SpyPushTokenRepository()
        await make(deliveryEnabled: false, repository: offRepository).execute(token: "fcm-token-2")
        #expect(await offRepository.uploaded.isEmpty)

        let repository = SpyPushTokenRepository()
        let sut = make(repository: repository)

        await sut.execute(token: "fcm-token-2")
        await sut.execute(token: "fcm-token-2")
        await sut.execute(token: "fcm-token-3")

        #expect(await repository.uploaded == ["fcm-token-2", "fcm-token-3"])
    }
}
