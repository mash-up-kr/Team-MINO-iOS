import FlowCoordination
import SwiftUI

/// 알림 탭 flow. 저장 오류 카드를 탭하면 안내 화면으로 push 된다(EC-013 — 어느 저장 오류 알림을
/// 눌러도 같은 화면이라 연관값이 없다).
public enum NotificationRoute: Hashable {
    case saveError
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class NotificationCoordinator: Coordinator {
    public var path: [NotificationRoute] = []
    public var sheet: Never?
    public var cover: Never?
    public let finish = FlowFinish<Never>()

    private let deps: NotificationDeps

    public init(deps: NotificationDeps) {
        self.deps = deps
    }

    // MARK: - Store Factory

    public func makeNotificationListStore() -> NotificationListStore {
        makeStore(
            NotificationListState(),
            reduce: notificationListReducer(useCase: deps.fetchNotifications),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    // MARK: - Navigation Routing

    func handle(_ nav: NotificationListNav) {
        switch nav {
        case .pushSaveError:
            push(.saveError)
        }
    }
}
