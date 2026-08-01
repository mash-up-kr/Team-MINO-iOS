import FeatureArchive
import FeatureHome
import FeatureOnboarding
import FeatureProfile
import SwiftUI

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 와 온보딩 flow 를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let profile: ProfileCoordinator

    /// 온보딩은 완주하면 버린다 — `OnboardingCoordinator` 는 flow 1회용이라 재사용하면
    /// 마지막 화면부터 뜨고 finish 도 다시 발사되지 않는다(타입 주석 참조).
    private(set) var onboarding: OnboardingCoordinator?

    init(deps: AppDependencies) {
        self.home = HomeCoordinator()
        self.archive = ArchiveCoordinator()
        self.profile = ProfileCoordinator()
        // 온보딩 표시 조건(최초 실행 여부 등) 판단은 아직 없다 — 지금은 항상 띄운다.
        self.onboarding = OnboardingCoordinator()
        bindOnboardingFinish()
    }

    private func bindOnboardingFinish() {
        onboarding?.finish.bind { [weak self] _ in
            self?.onboarding = nil
        }
    }
}
