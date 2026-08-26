import Domain

// [Convention] .claude/docs/mvi-coordinator-di.md §4 — Coordinator 별 좁은 deps 프로토콜, 자기 의존만 담는다.
public protocol NotificationDeps {
    var fetchNotifications: FetchNotificationsUseCase { get }
}
