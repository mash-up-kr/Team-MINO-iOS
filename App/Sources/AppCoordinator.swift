import FeatureArchive
import FeatureHome
import SwiftUI

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator

    init(deps: AppDependencies) {
        self.home = HomeCoordinator()
        self.archive = ArchiveCoordinator()
    }
}
