import FirebaseMessaging
import UserNotifications

/// 푸시가 화면에 뜨기 직전 iOS 가 깨우는 확장. 서버가 보내는 `aps.mutable-content: 1` 이 깨우는 대상이
/// 바로 이 클래스이고, 이게 없으면 그 플래그는 아무 일도 하지 않는다.
///
/// 하는 일은 하나 — `fcm_options.image` 의 URL 을 내려받아 알림에 첨부한다. 다운로드·첨부·실패 시
/// 원본 반환까지 전부 FCM SDK 가 처리하므로 우리가 직접 URLSession 을 돌리지 않는다.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)   // 손댈 수 없으면 원본을 그대로 통과시킨다
            return
        }
        bestAttemptContent = content
        Messaging.serviceExtension().populateNotificationContent(content, withContentHandler: contentHandler)
    }

    /// 30초를 넘기면 iOS 가 여기서 회수해 간다 — 이미지가 없더라도 알림 자체는 떠야 한다
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
