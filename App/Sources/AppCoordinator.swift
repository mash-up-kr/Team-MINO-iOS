import FeatureArchive
import FeatureHome
import FeatureProfile
import SwiftUI

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let profile: ProfileCoordinator

    init(deps: AppDependencies) {
        self.home = HomeCoordinator()
        self.archive = ArchiveCoordinator()
        self.profile = ProfileCoordinator()
    }
}
