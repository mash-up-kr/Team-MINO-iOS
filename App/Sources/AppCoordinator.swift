import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
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

    /// 자식 flow 를 만들 때마다 넘겨야 해서 보관한다 — 온보딩은 flow 1회당 새로 만든다.
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        self.home = HomeCoordinator(deps: deps)
        self.archive = ArchiveCoordinator(deps: deps)
        self.notification = NotificationCoordinator(deps: deps)
        self.profile = ProfileCoordinator()
        self.launch = AppLaunchStore(
            AppLaunchState(),
            reduce: appLaunchReducer(ensureSession: deps.ensureSession, onboarding: deps.onboarding)
        )
        // navigation 채널이 없는 flow 라(Nav == Never) observeNavigation 을 붙이지 않는다.
    }

    /// 온보딩 화면에 들어설 때 호출한다. **flow 1회당 새 인스턴스를 만든다** —
    /// 완주한 인스턴스를 재사용하면 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다
    /// (`OnboardingCoordinator` 타입 주석). 인스턴스는 화면(`OnboardingHost`)이 소유하고,
    /// `.main` 으로 넘어가면 그 화면과 함께 버려진다.
    func makeOnboarding() -> OnboardingCoordinator {
        let child = OnboardingCoordinator(deps: deps)
        child.finish.bind { [weak self] result in
            switch result {
            // 초대 착지는 딥링크 배선이 붙을 때 처리한다 — 지금은 방을 열 화면이 없다.
            // case 를 나열해 둬 결과가 늘면 컴파일이 여기서 깨진다.
            case .completed, .completedWithInvite:
                break
            }
            self?.launch.send(.onboardingFinished)
        }
        return child
    }
}
