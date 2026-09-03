import Domain
import Foundation

/// 푸시 메시지가 실어 온 `data` 를 이동 대상으로 옮긴다.
///
/// 서버는 목록 API 와 **같은 어휘**(`type` 문자열, `pinId`/`roomId`)를 쓰지만 **모양이 다르다** —
/// 목록은 `payload` 객체 안에 중첩하고 푸시는 평평하게 준다. 그래서 모양만 여기서 풀고
/// 유형·목적지 대응표는 `NotificationDTO` 의 것을 그대로 지난다. 표가 갈리면 같은 알림이
/// 목록에서와 푸시에서 서로 다른 곳으로 가게 된다.
///
/// 장소 알림은 `placeId` 와 `pinId` 를 **둘 다** 싣고 `pinId` 는 항상 온다(백엔드 확인 2026-09-03).
/// 그래도 없을 때를 `.unresolved` 로 흘리는 건, 빠진 걸 `placeId` 로 메우면 장소 마스터 id 가
/// `GET /pins/{id}` 로 나가 404 가 되기 때문이다 — 계약이 어긋난 날 조용히 틀린 요청을 보내느니
/// 알림 탭에서 끝내는 편이 낫다.
///
/// App 타깃이 부르는 자리라 이 타입만 `public` 이다(DTO 는 여전히 internal).
public enum PushNotificationPayload {
    /// `UNNotificationContent.userInfo`. APNs 가 얹는 `aps`·`gcm.*` 같은 키는 그냥 무시된다.
    ///
    /// **던지지 않는다.** 모르는 유형도, 식별자가 빠진 것도 `.unresolved` 로 흡수한다 —
    /// 사용자는 이미 알림을 눌렀고, 그 손짓에 오류 화면으로 답할 수는 없다.
    public static func destination(from userInfo: [AnyHashable: Any]) -> NotificationDestination {
        NotificationDTO.mapDestination(
            type: NotificationDTO.mapType(string(userInfo, "type") ?? ""),
            pinId: string(userInfo, "pinId"),
            roomId: string(userInfo, "roomId")
        )
    }

    /// APNs 는 값을 `NSString` 으로 얹어 준다 — `as? String` 이 그걸 받아 낸다.
    /// 숫자로 온 id 를 문자열로 되살리지는 않는다. 계약이 문자열이라 그런 값이 오면 계약 위반이고,
    /// 조용히 받아 주면 계약이 바뀐 사실이 묻힌다(`.unresolved` 로 떨어져 알림 탭에서 끝난다).
    private static func string(_ userInfo: [AnyHashable: Any], _ key: String) -> String? {
        NotificationDTO.trimmed(userInfo[key] as? String)
    }
}
