import Domain
import Foundation

/// `GET /api/v1/notifications` 의 항목 DTO.
/// [Convention] Packages/Data/Sources/Data/DTO/RoomDTO.swift — DTO 는 internal 로 닫아 Domain 에 노출되지 않게 한다
///
/// **표시 문자열을 옵셔널로 받는다.** `requestPage` 는 `[NotificationDTO]` 를 통째로 디코드하므로
/// 항목 하나에 키가 없으면 배열 전체가 실패해 **알림 탭이 통째로 죽는다**. 서버가 유형을 늘리거나
/// 필드를 바꿔도 화면이 살아 있도록 필수는 `id`·`type`·`createdAt` 셋만 둔다.
struct NotificationDTO: Decodable {
    let id: String
    let type: String
    /// 셀 첫 줄 — 서버가 완성해서 준다. 앱은 유형별 문구를 만들지 않는다.
    let typeLabel: String?
    /// 셀 둘째 줄 — 장소명·방 이름 등 대상 이름.
    let targetName: String?
    let thumbnailUrl: String?
    /// 이동 대상 식별자. 저장 오류는 `null` 이다.
    let payload: NotificationPayloadDTO?
    /// `APIDecoder` 의 custom 전략에 맡긴다 — 서버가 소수점 이하 초를 붙여 보내는데
    /// `Date(_:strategy: .iso8601)` 은 iOS 26 미만에서 그걸 거부한다(`APIDecoder` 주석의 실측).
    let createdAt: Date
}

/// 유형별로 오는 키가 달라 **전 필드를 옵셔널**로 연다.
///
/// 서버는 장소 대상 알림에 `placeId`(장소 마스터 id)도 함께 싣지만 **읽지 않는다** — 이동은
/// 핀 단위이고, 하나의 장소가 여러 방에 저장되면 핀이 여러 개라 장소 id 만으로는 어디를 열지
/// 정해지지 않는다. 어느 핀을 고를지는 서버가 유형별 정책으로 판단해 `pinId` 로 내려준다.
struct NotificationPayloadDTO: Decodable {
    /// 이동 대상 핀. `GET /pins/{pinId}` 에 그대로 넣고, 열 방은 그 응답의 `roomId` 가 정한다.
    let pinId: String?
    let roomId: String?
}

extension NotificationDTO {
    /// **던지지 않는다.** 알 수 없는 유형은 `.unknown(raw:)` 으로 흡수한다 — 모르는 알림 한 건 때문에
    /// 경계 매핑(`Networking.Page.toDomain`)의 `items.map` 이 페이지 전체를 실패시키면 알림 탭이 통째로 죽는다.
    func toDomain() -> AppNotification {
        let notificationType = Self.mapType(type)
        return AppNotification(
            id: NotificationID(id),
            type: notificationType,
            title: Self.trimmed(typeLabel) ?? "",
            targetName: Self.trimmed(targetName) ?? "",
            thumbnailURL: Self.parseImageURL(thumbnailUrl),
            destination: Self.mapDestination(type: notificationType, payload: payload),
            createdAt: createdAt
        )
    }

    /// 서버 유형 문자열 ↔ 도메인 유형의 **유일한 대응표**.
    static func mapType(_ raw: String) -> NotificationType {
        switch raw {
        case "PIN_DUPLICATED": .duplicateSave
        case "SAVE_FAILED": .saveError
        case "NEARBY_PLACE": .nearbyReminder
        case "TOP_COMMENTED_PLACE": .commentReminder
        case "ROOM_MEMBER_JOINED": .memberJoined
        case "ROOM_JOINED_SELF": .roomJoined
        default: .unknown(raw: raw)
        }
    }

    /// 유형이 요구하는 식별자를 payload 에서 뽑는다. **유형을 먼저 보고 그에 맞는 키만 읽는다** —
    /// 유형과 무관한 키가 섞여 와도 엉뚱한 곳으로 가지 않는다.
    ///
    /// `.unknown` 은 반드시 `.unresolved` 로 떨어진다(`NotificationType` 주석의 불변식) —
    /// 목록에서 걸러질 알림이 이동 경로를 갖고 있으면 안 된다.
    static func mapDestination(type: NotificationType, payload: NotificationPayloadDTO?) -> NotificationDestination {
        switch type {
        case .duplicateSave, .nearbyReminder, .commentReminder:
            // `placeId` 로 폴백하지 않는다 — 그건 장소 마스터 id 라 `GET /pins/{id}` 에 넣으면
            // 404 가 난다. 없으면 `.unresolved` 로 두는 편이(셀은 그리되 탭 무반응) 잘못된
            // 요청을 보내는 것보다 낫다.
            guard let id = Self.trimmed(payload?.pinId) else { return .unresolved }
            return .place(pinID: PinID(id))
        case .saveError:
            return .saveError
        case .memberJoined, .roomJoined:
            guard let id = Self.trimmed(payload?.roomId) else { return .unresolved }
            return .room(roomID: id)
        case .unknown:
            return .unresolved
        }
    }

    /// 공백뿐인 값도 "없는 것" 으로 본다
    private static func trimmed(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// http(s) 절대 주소만 남긴다 — 스킴 없는 문자열은 `URL(string:)` 이 상대 URL 로 **성공**시켜
    /// 엉뚱한 값이 이미지 주소로 둔갑한다(`RoomDTO.placeThumbnails` 와 같은 판단).
    private static func parseImageURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
