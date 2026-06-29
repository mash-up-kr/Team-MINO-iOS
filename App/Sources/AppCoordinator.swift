import SwiftUI
import Domain
import Feature

/// 앱 최상위 Coordinator. 자식 flow Coordinator 를 소유한다.
/// (탭/딥링크 디스패처는 화면이 늘면 추가 — 현재는 시범 flow 하나만 보유)
@Observable
@MainActor
final class AppCoordinator {
    let member: MemberCoordinator

    init(deps: AppDependencies) {
        self.member = MemberCoordinator(deps: deps, memberID: MemberID("1"))
    }
}
