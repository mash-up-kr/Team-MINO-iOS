import Foundation
import Domain

/// `GET /api/v1/notifications` 의 항목 DTO.
/// [Convention] Packages/Data/Sources/Data/DTO/RoomDTO.swift — DTO 는 internal 로 닫아 Domain 에 노출되지 않게 한다
///
/// **계약이 잠정이다**: Swagger 의 `type` 은 `"string"`, `payload` 는 `{}` 라 유형 문자열도
/// payload 키 이름도 확정된 게 없다. 확정되면 고치는 자리는 이 파일과 `NotificationType` 둘이다.
struct NotificationDTO: Decodable {
    let id: String
    let type: String
    let payload: NotificationPayloadDTO?
    /// 서버가 실어 보내지만 **Entity 로 옮기지 않는다** — 읽음 여부는 알림 도메인의 속성이 아니다
    /// (FR-016 · 스펙 §2.3). 응답에 실재하는 필드라 여기서는 받아 둔다.
    let readAt: String?
    let createdAt: String
}

/// 유형별로 오는 필드가 달라 **전 필드를 옵셔널**로 연다.
/// 잠정 계약이라 키가 늘거나 사라져도 응답 전체가 디코딩 실패하지 않아야 한다.
struct NotificationPayloadDTO: Decodable {
    let placeName: String?
    let placeImageUrl: String?
    let placeId: String?
    let roomName: String?
    let roomId: String?
    let participantName: String?
}

extension NotificationDTO {
    /// 경계(Data → Domain) 변환.
    ///
    /// **던지지 않는다.** 알 수 없는 유형은 `.unknown(raw:)` 으로 흡수한다 — 모르는 알림 한 건 때문에
    /// 경계 매핑(`Networking.Page.toDomain`)의 `items.map` 이 페이지 전체를 실패시키면 알림 탭이 통째로 죽는다.
    /// 이 저장소 선례도 흡수하는 쪽이다(`RoomDTO.toDomain` 의 `RoomType(rawValue:) ?? .shared`).
    func toDomain() -> AppNotification {
        let notificationType = Self.mapType(type)
        return AppNotification(
            id: NotificationID(id),
            type: notificationType,
            payload: Self.mapPayload(type: notificationType, dto: payload),
            createdAt: parseISO8601(createdAt)
        )
    }

    /// 서버 유형 문자열 ↔ 도메인 유형의 **유일한 대응표**.
    /// 모르는 문자열은 원문을 실어 `.unknown(raw:)` 으로 돌려준다.
    ///
    /// **문자열 값은 잠정이다** — Swagger 계약이 비어 있어(`type: "string"`) 확정된 서버 값이 없다.
    /// 여기 쓴 문자열은 도메인 케이스 이름을 그대로 옮긴 placeholder 이며, 계약이 확정되면 이 switch
    /// 한 곳만 고친다(파일 상단 주석).
    static func mapType(_ raw: String) -> NotificationType {
        switch raw {
        case "duplicateSave": .duplicateSave
        case "saveError": .saveError
        case "nearbyReminder": .nearbyReminder
        case "commentReminder": .commentReminder
        case "memberJoined": .memberJoined
        case "roomJoined": .roomJoined
        default: .unknown(raw: raw)
        }
    }

    /// 유형이 요구하는 값을 payload 에서 뽑는다. **유형을 먼저 보고 그에 맞는 값만 읽는다** —
    /// 이 순서가 `type` 과 `payload` 의 조합을 어긋나지 않게 하는 유일한 규칙이다.
    /// 유형이 요구하는 표시값이 없으면 `.unresolved`.
    static func mapPayload(type: NotificationType, dto: NotificationPayloadDTO?) -> NotificationPayload {
        switch type {
        case .duplicateSave, .nearbyReminder, .commentReminder:
            guard let name = Self.trimmed(dto?.placeName) else { return .unresolved }
            return .place(name: name, imageURL: Self.parseImageURL(dto?.placeImageUrl), placeID: dto?.placeId)
        case .saveError:
            return .saveError
        case .memberJoined:
            guard let roomName = Self.trimmed(dto?.roomName),
                  let participantName = Self.trimmed(dto?.participantName)
            else { return .unresolved }
            return .room(name: roomName, roomID: dto?.roomId, participantName: participantName)
        case .roomJoined:
            guard let roomName = Self.trimmed(dto?.roomName) else { return .unresolved }
            return .room(name: roomName, roomID: dto?.roomId, participantName: nil)
        case .unknown:
            return .unresolved
        }
    }

    /// 공백뿐인 값도 "없는 것" 으로 본다 — `!isEmpty` 만 쓰면 `" "` 같은 값이 통과해 셀 제목이
    /// 빈칸으로 그려진다(가드가 막으려던 바로 그 화면).
    private static func trimmed(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// `URL(string:)` 은 일반 텍스트도 상대 경로로 받아들여 거의 nil 을 내지 않고, 스킴만 보면
    /// `javascript:`·`file:` 같은 값도 통과한다 — 실제로 이미지를 가져올 수 있는 http(s) 절대
    /// 주소만 남긴다.
    ///
    /// **서버가 상대 경로를 줄 가능성은 아직 배제되지 않았다**(overview 열린 질문 5 — 이미지 주소
    /// 출처가 계약과 함께 미정). 그렇게 확정되면 이 함수가 base URL 결합을 더해야 할 자리다.
    private static func parseImageURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
