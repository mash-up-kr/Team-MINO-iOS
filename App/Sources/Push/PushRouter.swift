import UserNotifications

/// 원격 알림의 **표시와 탭**을 받는 `UNUserNotificationCenterDelegate`.
///
/// 탭은 `route` 로 흘러나간다 — 소비자가 늦게 꽂히는 사정은 ``PendingHandoff`` 주석 참조.
/// payload 를 읽지 않는 이유는 ``PushRoute`` 주석 참조.
@MainActor
final class PushRouter: NSObject, UNUserNotificationCenterDelegate {
    let route = PendingHandoff<PushRoute>()

    /// 포그라운드에서도 배너를 띄운다. **여기서 아무것도 안 하면 앱을 보고 있는 동안 온 알림은
    /// 통째로 사라진다** — iOS 기본값이 "표시 안 함"이다.
    ///
    /// `.badge` 는 넣지 않는다. 읽음 상태가 없어(FR-016) 뱃지를 내릴 자리가 없다 — 숫자만 쌓인다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 밀어서 지운 것도 여기로 온다 — 그걸로 화면을 바꾸면 안 된다.
        let isDismiss = response.actionIdentifier == UNNotificationDismissActionIdentifier
        // payload 해석을 **여기서 끝낸다.** `userInfo`([AnyHashable: Any])는 Sendable 이 아니라
        // Task 안으로 들고 들어갈 수 없다 — 격리 경계를 넘는 건 값이 정해진 `PushRoute` 여야 한다.
        let route = PushRoute(userInfo: response.notification.request.content.userInfo)

        // 남은 일이 화면 전환뿐이라 시스템에는 즉시 끝났다고 알린다. 완료 핸들러도 논-Sendable 이라
        // Task 안에서 부르면 같은 이유로 막힌다.
        completionHandler()
        guard !isDismiss else { return }

        Task { @MainActor in self.route.deliver(route) }
    }
}
