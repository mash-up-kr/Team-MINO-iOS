import Domain
import FlowCoordination
import MVI
import SwiftUI

/// 알림 탭 flow. 저장 오류 카드를 탭하면 안내 화면으로 push 된다(EC-013 — 어느 저장 오류 알림을
/// 눌러도 같은 화면이라 연관값이 없다).
public enum NotificationRoute: Hashable {
    case saveError
}

/// 알림 탭이 **탭 밖으로** 요청하는 이동. 조회가 끝난 완성 객체를 싣는다.
///
/// 알림 탭은 저장 탭을 알지 못하므로(Feature 간 의존 금지) 여기까지만 만들고, 어느 탭에서 어떻게
/// 여는지는 컴포지션 루트(`AppCoordinator`)가 정한다.
public enum NotificationCrossTabDestination: Equatable, Sendable {
    /// 장소 상세. 배경 지도가 방에 의존해 방을 함께 싣는다 —
    /// 도착지 방은 알림이 아니라 그 핀이 속한 방이 정한다(FR-022).
    case place(pin: Pin, room: Room)
    case room(Room)
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class NotificationCoordinator: Coordinator {
    public var path: [NotificationRoute] = []
    public var sheet: Never?
    public var cover: Never?
    public let finish = FlowFinish<Never>()

    /// 탭 밖으로 나가는 이동을 상위(`AppCoordinator`)에 넘기는 채널.
    ///
    /// `FlowFinish` 를 쓰지 않는 이유: 탭 flow 는 `Output == Never` 라 발사 자체가 컴파일 불가이고,
    /// 애초에 1회성 종료 보고용이라 반복되는 이동과 맞지 않는다(.claude/docs/mvi-coordinator-di.md §3).
    public var onCrossTab: ((NotificationCrossTabDestination) -> Void)?

    private let deps: NotificationDeps

    public init(deps: NotificationDeps) {
        self.deps = deps
    }

    // MARK: - Store Factory

    public func makeNotificationListStore() -> NotificationListStore {
        Store(
            NotificationListState(),
            reduce: notificationListReducer(
                useCase: deps.fetchNotifications,
                fetchPinDetail: deps.fetchPinDetail,
                fetchRoom: deps.fetchRoom
            ),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    // MARK: - Navigation Routing

    func handle(_ nav: NotificationListNav) {
        switch nav {
        case .pushSaveError:
            push(.saveError)
        case .openCrossTab(let destination):
            onCrossTab?(destination)
        }
    }
}
