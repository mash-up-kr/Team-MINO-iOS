import Core
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
import Logging
import SwiftUI

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 와 진입 게이트를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let notification: NotificationCoordinator
    let profile: ProfileCoordinator

    /// 앱 진입 게이트. 화면 Store 와 달리 **앱 수명과 같아** Coordinator 가 직접 든다 —
    /// 온보딩 완료 보고를 여기로 밀어넣어야 해서 View 의 `@State` 에 둘 수 없다.
    let launch: AppLaunchStore

    /// 도착했지만 아직 쓸 수 없는 딥링크. `launch` 와 같은 이유로 여기 있다 — 앱 수명과 같은 상태라
    /// 화면의 `@State` 에 두면 진입 게이트가 화면을 갈아끼울 때 함께 버려진다.
    private let pendingDeeplink = PendingDeeplink()

    /// 자식 flow 를 만들 때마다 넘겨야 해서 보관한다 — 온보딩은 flow 1회당 새로 만든다.
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        self.home = HomeCoordinator(deps: deps)
        self.archive = ArchiveCoordinator(deps: deps)
        self.notification = NotificationCoordinator(deps: deps)
        self.profile = ProfileCoordinator(deps: deps)
        self.launch = AppLaunchStore(
            AppLaunchState(),
            reduce: appLaunchReducer(ensureSession: deps.ensureSession, fetchProfile: deps.fetchProfile)
        )
        // navigation 채널이 없는 flow 라(Nav == Never) observeNavigation 을 붙이지 않는다.
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
