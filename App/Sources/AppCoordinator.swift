import Feature
import FeatureArchive
import FeatureHome
import FeatureOnboarding
import FeatureProfile
import SwiftUI

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 와 진입 게이트를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let profile: ProfileCoordinator

    /// 앱 진입 게이트. 화면 Store 와 달리 **앱 수명과 같아** Coordinator 가 직접 든다 —
    /// 온보딩 완료 보고를 여기로 밀어넣어야 해서 View 의 `@State` 에 둘 수 없다.
    let launch: AppLaunchStore

    private(set) var onboarding: OnboardingCoordinator?

    init(deps: AppDependencies) {
        self.home = HomeCoordinator(deps: deps)
        self.archive = ArchiveCoordinator(deps: deps)
        self.profile = ProfileCoordinator()
        self.launch = AppLaunchStore(
            AppLaunchState(),
            reduce: appLaunchReducer(ensureSession: deps.ensureSession, onboarding: deps.onboarding)
        )
        // navigation 채널이 없는 flow 라(Nav == Never) observeNavigation 을 붙이지 않는다.
    }

    /// 온보딩 화면에 들어설 때 호출한다.
    ///
    /// 완주한 인스턴스를 버리지 않고 들고 있는다. 온보딩은 완료 플래그가 남는 순간 다시 뜨지
    /// 않으므로 재사용 위험이 없고, `finish` 직후 nil 로 비우면 아직 `.main` 으로 넘어가기 전
    /// 한 프레임에 이 메서드가 다시 불려 **온보딩이 처음부터 새로 뜬다.**
    func makeOnboarding() -> OnboardingCoordinator {
        if let onboarding { return onboarding }

        let child = OnboardingCoordinator()
        child.finish.bind { [weak self] result in
            switch result {
            case .completed:
                break
            case .completedWithInvite:
                // 초대 착지는 딥링크 배선이 붙을 때 처리한다 — 지금은 방을 열 화면이 없다.
                // case 를 열어둬 그때 컴파일러가 이 자리를 가리키게 한다.
                break
            }
            self?.launch.send(.onboardingFinished)
        }
        onboarding = child
        return child
    }
}
