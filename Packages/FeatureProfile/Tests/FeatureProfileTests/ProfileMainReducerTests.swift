import Domain
import MVITestSupport
import Testing
@testable import FeatureProfile

@MainActor
struct ProfileMainReducerTests {
    private func makeStore(
        fetchProfile: FetchProfileUseCase = StubFetchProfileUseCase(),
        notification: NotificationSettingUseCase = StubNotificationSettingUseCase(),
        location: LocationSettingUseCase = StubLocationSettingUseCase()
    ) -> TestStore<ProfileMainState, ProfileMainAction, ProfileMainNav> {
        TestStore(
            ProfileMainState(),
            reduce: profileMainReducer(
                fetchProfile: fetchProfile,
                notification: notification,
                location: location
            )
        )
    }

    // MARK: - 프로필 조회 (FR-001 / FR-009)

    @Test("L2 — 조회에 성공하면 닉네임과 아바타가 채워진다")
    func loadProfile_success_fillsSummary() async {
        let store = makeStore()

        await store.send(.loadProfile)
        await store.receive(.profileLoaded(Profile(nickname: "홍길동", avatarID: 7))) {
            $0.nickname = "홍길동"
            $0.avatarIndex = 7
        }

        store.finish()
    }

    // 한 번도 못 읽었으면 프로필 영역은 빈 채로 남는다 — 앱 설정·서비스 정보는 그대로 그린다.
    @Test("L2 — 최초 조회에 실패하면 프로필 영역이 빈 채로 남는다")
    func loadProfile_firstFailure_leavesSummaryEmpty() async {
        let store = makeStore(fetchProfile: StubFetchProfileUseCase(error: .profileFetchFailed))

        await store.send(.loadProfile)
        await store.receive(.profileLoadFailed(.profileFetchFailed))

        #expect(store.currentState.nickname.isEmpty)
        #expect(store.currentState.avatarIndex == nil)
        // 스위치는 손대지 않는다.
        #expect(!store.currentState.isNotificationOn)
        #expect(store.currentState.dialog == nil)
        store.finish()
    }

    // 재조회는 복귀할 때마다 일어난다(FR-009). 저장하고 돌아온 직후 잠깐 끊긴 것만으로
    // 방금 저장한 프로필이 사라져 보이면 안 되고, 그 상태로 연필을 누르면 편집 화면이
    // 빈 채로 열려 FR-002 까지 깨진다.
    @Test("L2 — 재조회에 실패해도 마지막으로 읽은 프로필을 지우지 않는다")
    func loadProfile_refreshFailure_keepsLastKnownProfile() async {
        let store = makeStore(fetchProfile: StubFetchProfileUseCase(error: .profileFetchFailed))

        await store.send(.profileLoaded(Profile(nickname: "홍길동", avatarID: 7))) {
            $0.nickname = "홍길동"
            $0.avatarIndex = 7
        }
        await store.send(.loadProfile)
        await store.receive(.profileLoadFailed(.profileFetchFailed))   // state 변화 없음

        #expect(store.currentState.nickname == "홍길동")
        #expect(store.currentState.avatarIndex == 7)

        // 그래서 편집 진입도 기존 값을 그대로 실어 보낸다(FR-002).
        await store.send(.tapEditProfile)
        store.receiveNavigation(.pushProfileSetup(nickname: "홍길동", avatarIndex: 7))
        store.finish()
    }

    // MARK: - 스위치 동기화 (FR-009)

    @Test("L2 — 진입 시 두 스위치가 실제 상태와 동기화된다 — 다른 진입점에서 켜진 권한도 반영한다")
    func syncSwitches_reflectsActualState() async {
        let store = makeStore(
            notification: StubNotificationSettingUseCase(isOn: true),
            location: StubLocationSettingUseCase(isOnValue: true)
        )

        await store.send(.syncSwitches)
        await store.receive(.switchesSynced(isNotificationOn: true, isLocationOn: true)) {
            $0.isNotificationOn = true
            $0.isLocationOn = true
        }

        store.finish()
    }

    // MARK: - 알림 스위치 (FR-007 / FR-014 / UX-003)

    @Test("L2 — 알림을 켜 권한이 허용되면 스위치가 ON 이 된다")
    func notification_turnOn_whenGranted() async {
        let store = makeStore(notification: StubNotificationSettingUseCase(activation: .activated))

        await store.send(.setNotification(true)) { $0.isNotificationBusy = true }
        await store.receive(.notificationActivated(.activated)) {
            $0.isNotificationBusy = false
            $0.isNotificationOn = true
        }

        store.finish()
    }

    // 권한 팝업이 뜨는 사이 앱이 비활성→활성으로 돌아오며 재조회가 발사된다. 그 결과가 늦게
    // 도착해 방금 확정된 값을 되돌리면, 권한을 허용했는데 스위치만 꺼져 보인다.
    @Test("L2 — 요청 중 도착한 재조회 결과가 진행 중인 축을 덮지 않는다")
    func syncSwitches_doesNotOverwriteInFlightToggle() async {
        let store = makeStore(notification: StubNotificationSettingUseCase(activation: .activated))

        await store.send(.setNotification(true)) { $0.isNotificationBusy = true }
        // 권한이 허용되기 전 시점의 스냅샷이 늦게 도착한다.
        await store.send(.switchesSynced(isNotificationOn: false, isLocationOn: true)) {
            $0.isLocationOn = true      // 진행 중이 아닌 축은 정상 반영된다
        }
        #expect(!store.currentState.isNotificationOn)

        await store.receive(.notificationActivated(.activated)) {
            $0.isNotificationBusy = false
            $0.isNotificationOn = true
        }
        #expect(store.currentState.isNotificationOn)
        store.finish()
    }

    // 시스템 팝업이 떠 있는 사이 한 번 더 누르면 반대 방향 요청이 들어가, 위치에선
    // "끌 수 없어요" 안내가 권한이 꺼진 상태에서 뜨는 엉뚱한 경로가 된다.
    @Test("L2 — 요청 중 재탭은 무시된다")
    func setSwitch_whileBusy_isIgnored() async {
        let store = makeStore(location: StubLocationSettingUseCase(activation: .rejected))

        await store.send(.setLocation(true)) { $0.isLocationBusy = true }
        await store.send(.setLocation(false))    // 무시 — 다이얼로그가 뜨면 안 된다
        #expect(store.currentState.dialog == nil)

        await store.receive(.locationActivated(.rejected)) { $0.isLocationBusy = false }
        #expect(!store.currentState.isLocationOn)
        store.finish()
    }

    // UX-003 — 권한이 확정되기 전에 미리 ON 으로 바뀌지 않는다.
    @Test("L2 — 시스템 팝업에서 거부하면 스위치가 OFF 로 남는다")
    func notification_turnOn_whenRejected_staysOff() async {
        let store = makeStore(notification: StubNotificationSettingUseCase(activation: .rejected))

        await store.send(.setNotification(true)) { $0.isNotificationBusy = true }
        await store.receive(.notificationActivated(.rejected)) { $0.isNotificationBusy = false }

        #expect(!store.currentState.isNotificationOn)
        #expect(store.currentState.dialog == nil)
        store.finish()
    }

    @Test("L2 — 이미 거부돼 팝업이 안 뜨면 설정 이동 안내를 띄운다")
    func notification_turnOn_whenBlocked_showsDialog() async {
        let store = makeStore(notification: StubNotificationSettingUseCase(activation: .needsSystemSettings))

        await store.send(.setNotification(true)) { $0.isNotificationBusy = true }
        await store.receive(.notificationActivated(.needsSystemSettings)) {
            $0.isNotificationBusy = false
            $0.dialog = .notificationBlocked
        }

        #expect(!store.currentState.isNotificationOn)
        store.finish()
    }

    @Test("L2 — 알림을 끄면 OS 권한은 두고 앱 발송만 멈춘다")
    func notification_turnOff_keepsPermission() async {
        let notification = StubNotificationSettingUseCase(isOn: true)
        let store = makeStore(notification: notification)

        await store.send(.switchesSynced(isNotificationOn: true, isLocationOn: false)) {
            $0.isNotificationOn = true
        }
        await store.send(.setNotification(false)) { $0.isNotificationBusy = true }
        await store.receive(.notificationTurnedOff) {
            $0.isNotificationBusy = false
            $0.isNotificationOn = false
        }

        #expect(notification.didTurnOff)
        // 끄기는 권한을 건드리지 않으므로 안내 다이얼로그가 없다 — 위치와 갈리는 지점이다.
        #expect(store.currentState.dialog == nil)
        store.finish()
    }

    // MARK: - 위치 스위치 (FR-008 / FR-015)

    @Test("L2 — 위치를 켜 권한이 허용되면 스위치가 ON 이 된다")
    func location_turnOn_whenGranted() async {
        let store = makeStore(location: StubLocationSettingUseCase(activation: .activated))

        await store.send(.setLocation(true)) { $0.isLocationBusy = true }
        await store.receive(.locationActivated(.activated)) {
            $0.isLocationBusy = false
            $0.isLocationOn = true
        }

        store.finish()
    }

    @Test("L2 — 이미 거부돼 팝업이 안 뜨면 설정 이동 안내를 띄운다")
    func location_turnOn_whenBlocked_showsDialog() async {
        let store = makeStore(location: StubLocationSettingUseCase(activation: .needsSystemSettings))

        await store.send(.setLocation(true)) { $0.isLocationBusy = true }
        await store.receive(.locationActivated(.needsSystemSettings)) {
            $0.isLocationBusy = false
            $0.dialog = .locationBlocked
        }

        store.finish()
    }

    // FR-015 — 앱은 이미 준 위치 권한을 스스로 취소할 수 없다. 스위치는 켜진 채로 남는다.
    @Test("L1 — 켜진 위치를 끄려 하면 안내만 띄우고 스위치는 그대로 둔다")
    func location_turnOff_showsDialogAndKeepsOn() async {
        let store = makeStore()

        await store.send(.switchesSynced(isNotificationOn: false, isLocationOn: true)) {
            $0.isLocationOn = true
        }
        await store.send(.setLocation(false)) { $0.dialog = .locationTurnOff }

        #expect(store.currentState.isLocationOn)
        store.finish()
    }

    // MARK: - 다이얼로그 (EC-003 / EC-007)

    @Test("L2 — 안내의 확인은 OS 설정으로 보낸다")
    func confirmDialog_opensSystemSettings() async {
        let store = makeStore()

        await store.send(.setLocation(false)) { $0.dialog = .locationTurnOff }
        await store.send(.confirmDialog) { $0.dialog = nil }
        store.receiveNavigation(.openSystemSettings)

        store.finish()
    }

    @Test("L2 — 안내의 취소는 아무 데도 보내지 않는다")
    func dismissDialog_navigatesNowhere() async {
        let store = makeStore()

        await store.send(.setLocation(false)) { $0.dialog = .locationTurnOff }
        await store.send(.dismissDialog) { $0.dialog = nil }

        // finish 가 미수신 navigation 잔여를 검사한다 — openSystemSettings 가 나갔다면 여기서 실패한다.
        store.finish()
    }

    // MARK: - 진입점 (FR-002 / FR-011 / FR-012)

    @Test("L2 — 프로필 편집은 현재 값을 실어 보낸다")
    func tapEditProfile_carriesCurrentProfile() async {
        let store = makeStore()

        await store.send(.profileLoaded(Profile(nickname: "홍길동", avatarID: 7))) {
            $0.nickname = "홍길동"
            $0.avatarIndex = 7
        }
        await store.send(.tapEditProfile)
        store.receiveNavigation(.pushProfileSetup(nickname: "홍길동", avatarIndex: 7))

        store.finish()
    }

    @Test("L2 — 약관 및 동의는 지정된 노션 문서를 연다")
    func tapTerms_opensTermsDocument() async {
        let store = makeStore()

        await store.send(.tapTerms)
        store.receiveNavigation(.openURL(ProfileServiceLinks.terms))

        store.finish()
    }

    // 앱 ID 가 정해지기 전까지는 열 곳이 없다 — 눌러도 아무 일이 없어야 한다.
    @Test("L2 — 앱 ID 가 없으면 앱 리뷰는 아무 데도 보내지 않는다")
    func tapAppReview_withoutAppStoreID_navigatesNowhere() async throws {
        try #require(ProfileServiceLinks.appReview == nil, "앱 ID 가 정해졌다면 이 테스트를 실제 이동 검증으로 바꾼다")
        let store = makeStore()

        await store.send(.tapAppReview)

        store.finish()
    }
}
