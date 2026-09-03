import Core
import Domain
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
import Logging
import SwiftUI

/// 탭 밖에서 들어오는 이동의 도착지. **장소·방 모두 저장 탭에서 연다** — 홈 탭도 같은 장소 상세를
/// 열 수 있지만, 저장 탭이 방 상세와 장소 상세를 모두 갖고 있어 한 곳으로 모은다.
enum AppDestination: Equatable {
    case place(pin: Pin, room: Room)
    case room(Room)
}

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 와 진입 게이트를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let notification: NotificationCoordinator
    let profile: ProfileCoordinator

    /// 지금 보고 있는 탭. **View 의 `@State` 가 아니라 여기 있다** — 알림에서 저장 탭으로 넘기는
    /// 것처럼 코드가 탭을 바꿔야 하는 경로가 있어서다(딥링크·푸시도 같은 자리를 쓰게 된다).
    ///
    /// `MainTab` 이 아니라 `Int` 인 이유: `MHTabBar` 가 `Binding<Int>` 를 받는다. 여기서 `MainTab`
    /// 으로 들면 뷰마다 변환 Binding 을 손으로 만들어야 한다.
    var selectedTabID: Int = MainTab.home.rawValue

    /// 앱 진입 게이트. 화면 Store 와 달리 **앱 수명과 같아** Coordinator 가 직접 든다 —
    /// 온보딩 완료 보고를 여기로 밀어넣어야 해서 View 의 `@State` 에 둘 수 없다.
    let launch: AppLaunchStore

    /// 도착했지만 아직 쓸 수 없는 딥링크. `launch` 와 같은 이유로 여기 있다 — 앱 수명과 같은 상태라
    /// 화면의 `@State` 에 두면 진입 게이트가 화면을 갈아끼울 때 함께 버려진다.
    private let pendingDeeplink = PendingDeeplink()

    /// 푸시 토큰을 서버와 맞추는 일. `launch` 와 같은 이유로 여기 있다 — 화면이 아니라 앱 수명이다.
    let pushTokenSync: PushTokenSync

    /// 아직 메인이 아닐 때 도착한 푸시. 콜드런치에서 알림을 누르면 화면은 스플래시고 **탭이 아직
    /// 없다**(`RootView` 가 `.main` 에서만 `MainTabView` 를 만든다). `.main` 에 들어설 때까지 들고
    /// 있다가 그때 소비한다 — 바로 위 `pendingDeeplink` 와 같은 문제·같은 해법이다.
    ///
    /// 온보딩 중이면 온보딩을 마친 뒤에 열린다. 그 사이 앱이 죽어 보관분이 사라지는 건 허용한다 —
    /// 알림은 목록에 그대로 남아 있어 다시 누르면 된다.
    private var pendingPush: NotificationDestination?

    /// 콜드런치로 들어온 푸시의 도착지를 아직 조회 중이다. 참인 동안 `RootView` 는 **스플래시를
    /// 유지한다** — 조회가 끝나기 전에 메인 탭을 그리면 홈 탭이 잠깐 보였다가 저장 탭으로 튄다.
    ///
    /// 이미 메인이 떠 있는 상태(백그라운드 복귀)에서는 켜지 않는다. 보고 있던 화면을 스플래시로
    /// 덮는 게 더 이상하다 — 그 경우엔 보던 탭에 머물다 조회가 끝나면 옮겨 간다.
    private(set) var isResolvingPush = false

    /// 자식 flow 를 만들 때마다 넘겨야 해서 보관한다 — 온보딩은 flow 1회당 새로 만든다.
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        self.pushTokenSync = deps.pushTokenSync
        self.home = HomeCoordinator(deps: deps)
        self.archive = ArchiveCoordinator(deps: deps)
        self.notification = NotificationCoordinator(deps: deps)
        self.profile = ProfileCoordinator(deps: deps)
        self.launch = AppLaunchStore(
            AppLaunchState(),
            reduce: appLaunchReducer(ensureSession: deps.ensureSession, fetchProfile: deps.fetchProfile)
        )
        // navigation 채널이 없는 flow 라(Nav == Never) observeNavigation 을 붙이지 않는다.

        // 알림 탭이 탭 밖으로 내보내는 이동을 여기서 받는다. 자식이 부모를 알지 못하게
        // 콜백으로만 잇는다(retain cycle 방지: weak).
        notification.onCrossTab = { [weak self] destination in
            switch destination {
            case .place(let pin, let room): self?.open(.place(pin: pin, room: room))
            case .room(let room): self?.open(.room(room))
            }
        }
    }

    /// 탭 밖에서 들어오는 이동의 **유일한 진입점**. 알림이 첫 소비자이고, 딥링크·푸시가 붙을 때도
    /// 같은 함수를 부른다 — 경로마다 진입점을 쪼개면 탭 전환 규칙이 그만큼 갈라진다.
    ///
    /// **동기여야 한다.** `archive.open` 이 서는 순간 저장 탭이 탭바를 감추는 화면이 되는데
    /// (`ArchiveCoordinator.isFullBleedContentPresented`), 여기에 `await` 가 끼면 아직 알림 탭인 채로
    /// 탭바만 사라지는 프레임이 생긴다. 그래서 조회는 부르는 쪽이 끝내고 객체를 넘긴다.
    func open(_ destination: AppDestination) {
        switch destination {
        case .place(let pin, let room): archive.open(pin: pin, in: room)
        case .room(let room): archive.open(room: room)
        }
        selectedTabID = MainTab.save.rawValue
    }

    /// 푸시를 눌렀을 때의 진입점. 메인이 아직 아니면 들고 있다가 `mainDidAppear()` 가 소비한다.
    func handle(push destination: NotificationDestination) {
        guard launch.state.phase == .main else {
            pendingPush = destination
            // 메인이 그려지기 **전에** 켜 둔다 — `.main` 에 들어서는 순간 스플래시가 이어지고
            // 메인 탭은 도착지가 정해진 뒤에 한 번만 그려진다.
            isResolvingPush = true
            return
        }
        resolve(destination)
    }

    /// 메인 진입 시점(`RootView`)에 부른다. 스플래시를 유지하는 동안에도 불려야 해서
    /// `MainTabView` 가 아니라 `.main` 분기 자체에 걸린다 — 아니면 보관분을 꺼낼 사람이 없다.
    func mainDidAppear() {
        pushTokenSync.kick()
        guard let destination = pendingPush else { return }
        pendingPush = nil
        resolve(destination)
    }

    /// 포그라운드 복귀. 토큰 업로드의 사실상 재시도 지점이다 — 별도 재시도 타이머를 두지 않는 근거다.
    func didBecomeActive() {
        guard launch.state.phase == .main else { return }
        pushTokenSync.kick()
    }

    /// 알림이 가리키는 곳을 열어 준다.
    ///
    /// `open(_:)` 이 완성된 `Pin`·`Room` 을 요구해서(동기여야 하는 이유는 그쪽 주석) 여기서 조회를
    /// 끝내고 넘긴다 — 알림 셀 탭(`NotificationListStore`)이 하는 것과 같은 흐름이다.
    private func resolve(_ destination: NotificationDestination) {
        switch destination {
        case .place(let pinID):
            Task { [weak self] in
                guard let self else { return }
                do {
                    let pin = try await deps.fetchPinDetail.execute(pinID: pinID).pin
                    // 열 방은 알림이 아니라 핀이 정한다(FR-022).
                    let room = try await deps.fetchRoom.execute(id: pin.roomID)
                    finishPush { $0.open(.place(pin: pin, room: room)) }
                } catch {
                    finishPush { $0.landOnNotificationTab() }
                }
            }
        case .room(let roomID):
            Task { [weak self] in
                guard let self else { return }
                do {
                    let room = try await deps.fetchRoom.execute(id: roomID)
                    finishPush { $0.open(.room(room)) }
                } catch {
                    finishPush { $0.landOnNotificationTab() }
                }
            }
        // 저장 오류 안내는 알림 탭 안의 화면이다(EC-013). 목록에 그 알림이 있으니 탭까지만 보내면
        // 사용자가 눌러 들어갈 수 있다 — 밖에서 그 화면을 직접 여는 진입점은 아직 없다.
        case .saveError, .unresolved:
            finishPush { $0.landOnNotificationTab() }
        }
    }

    /// 도착지가 정해졌다 — 이동하고 스플래시를 내린다. **순서가 중요하다**: 먼저 이동해 두지
    /// 않으면 메인 탭이 한 프레임 동안 홈으로 그려진 뒤 옮겨 간다.
    private func finishPush(_ move: (AppCoordinator) -> Void) {
        move(self)
        isResolvingPush = false
    }

    private func landOnNotificationTab() {
        selectedTabID = MainTab.notification.rawValue
    }

    /// 온보딩 화면에 들어설 때 호출한다. **flow 1회당 새 인스턴스를 만든다** —
    /// 완주한 인스턴스를 재사용하면 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다
    /// (`OnboardingCoordinator` 타입 주석). 인스턴스는 화면(`OnboardingHost`)이 소유하고,
    /// `.main` 으로 넘어가면 그 화면과 함께 버려진다.
    func makeOnboarding() -> OnboardingCoordinator {
        let child = OnboardingCoordinator(deps: deps, inviteCode: consumePendingInviteCode())
        child.finish.bind { [weak self] result in
            switch result {
            // 초대 착지(Flow 6 의 방 상세)는 후속이다 — 이 브랜치는 진입점까지만 잇는다.
            // case 를 나열해 둬 결과가 늘면 컴파일이 여기서 깨진다.
            case .completed, .completedWithInvite:
                break
            }
            self?.launch.send(.onboardingFinished)
        }
        return child
    }

    /// 외부에서 들어온 URL 의 유일한 진입점(`MINOApp` 의 `.onOpenURL`).
    ///
    /// 지금은 **보관만 한다.** 꺼내 가는 곳은 온보딩(`makeOnboarding`) 하나뿐이고,
    /// 온보딩을 마친 사용자용 착지는 후속에서 붙는다.
    func handle(_ url: URL) {
        guard let deeplink = deps.deeplinkParser.parse(url) else {
            // 파서가 앱의 신뢰 경계다 — 해석되지 않는 링크는 되살리지 않고 버린다.
            // 코드 값은 남기지 않는다(로그로 새는 초대 링크는 그 자체로 방 접근권이다).
            Log.notice("해석하지 못한 딥링크를 버린다", metadata: ["scheme": url.scheme ?? "-"])
            return
        }
        Log.info("딥링크 보관")
        pendingDeeplink.store(deeplink)
    }

    /// 대기 중인 딥링크가 초대면 그 코드를 꺼낸다.
    /// 목적지가 늘면 이 switch 가 컴파일에서 걸려 "온보딩에 뭘 넘길지" 를 다시 정하게 만든다.
    private func consumePendingInviteCode() -> String? {
        switch pendingDeeplink.consume() {
        case .invite(let code)?: code
        case nil: nil
        }
    }
}
