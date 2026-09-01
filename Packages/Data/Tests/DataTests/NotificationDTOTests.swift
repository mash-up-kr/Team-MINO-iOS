import Foundation
import Networking
import Testing
import Domain
@testable import Data

/// 이 스위트가 **서버 `type` 문자열과 도착지 사이의 대응을 강제하는 유일한 장치**다 — 대응표를
/// 고치면 여기가 먼저 깨진다. 표시 문구는 서버가 완성해서 주므로 매핑 대상이 아니다.
@Suite("NotificationDTO → AppNotification 매핑")
struct NotificationDTOTests {
    private static let iso = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private func decode(_ json: String) throws -> NotificationDTO {
        try APIDecoder.make().decode(NotificationDTO.self, from: Data(json.utf8))
    }

    private func decodeList(_ json: String) throws -> [NotificationDTO] {
        try APIDecoder.make().decode([NotificationDTO].self, from: Data(json.utf8))
    }

    private func json(
        id: String = "n1",
        type: String = "PIN_DUPLICATED",
        typeLabel: String? = "이미 저장해둔 곳이에요",
        targetName: String? = "패스트리 순간",
        thumbnailUrl: String? = nil,
        payload: String? = nil,
        createdAt: String = "2026-09-01T12:00:00.000Z"
    ) -> String {
        var fields = ["\"id\":\"\(id)\"", "\"type\":\"\(type)\"", "\"createdAt\":\"\(createdAt)\""]
        if let typeLabel { fields.append("\"typeLabel\":\"\(typeLabel)\"") }
        if let targetName { fields.append("\"targetName\":\"\(targetName)\"") }
        if let thumbnailUrl { fields.append("\"thumbnailUrl\":\"\(thumbnailUrl)\"") }
        if let payload { fields.append("\"payload\":\(payload)") }
        return "{\(fields.joined(separator: ","))}"
    }

    // MARK: - 유형 → 도착지

    @Test("장소 대상 3종은 payload.placeId 를 핀 id 로 읽는다", arguments: [
        "PIN_DUPLICATED", "NEARBY_PLACE", "TOP_COMMENTED_PLACE",
    ])
    func mapsPlaceTypesToPinDestination(_ type: String) throws {
        let dto = try decode(json(type: type, payload: #"{"placeId":"pin-1"}"#))

        #expect(dto.toDomain().destination == .place(pinID: PinID("pin-1")))
    }

    @Test("방 대상 2종은 payload.roomId 를 읽는다", arguments: [
        "ROOM_MEMBER_JOINED", "ROOM_JOINED_SELF",
    ])
    func mapsRoomTypesToRoomDestination(_ type: String) throws {
        let dto = try decode(json(type: type, payload: #"{"roomId":"room-1"}"#))

        #expect(dto.toDomain().destination == .room(roomID: "room-1"))
    }

    @Test("저장 오류는 payload 없이 저장 오류 안내로 간다")
    func mapsSaveFailedWithoutPayload() throws {
        let dto = try decode(json(type: "SAVE_FAILED", payload: nil))
        let notification = dto.toDomain()

        #expect(notification.type == .saveError)
        #expect(notification.destination == .saveError)
    }

    // 목록에서 걸러질 알림이 이동 경로를 갖고 있으면, 필터를 한 줄 놓치는 순간 엉뚱한 곳으로 간다.
    @Test("모르는 유형은 원문을 보존하고 도착지는 반드시 unresolved 다")
    func unknownTypeAlwaysResolvesToUnresolved() throws {
        let dto = try decode(json(type: "REALLY_NEW_KIND", payload: #"{"placeId":"pin-1"}"#))
        let notification = dto.toDomain()

        #expect(notification.type == .unknown(raw: "REALLY_NEW_KIND"))
        #expect(notification.destination == .unresolved)
    }

    @Test("유형과 무관한 키가 섞여 와도 그 유형이 요구하는 키만 읽는다")
    func readsOnlyTheKeyTheTypeRequires() throws {
        let place = try decode(json(type: "PIN_DUPLICATED", payload: #"{"roomId":"room-1"}"#))
        let room = try decode(json(type: "ROOM_JOINED_SELF", payload: #"{"placeId":"pin-1"}"#))

        #expect(place.toDomain().destination == .unresolved)
        #expect(room.toDomain().destination == .unresolved)
    }

    @Test("payload 키가 통째로 없거나 식별자가 공백뿐이면 도착지가 없다", arguments: [
        nil, "{}", #"{"placeId":null}"#, #"{"placeId":"   "}"#,
    ])
    func missingIdentifierBecomesUnresolved(_ payload: String?) throws {
        let dto = try decode(json(type: "PIN_DUPLICATED", payload: payload))

        #expect(dto.toDomain().destination == .unresolved)
    }

    // MARK: - 표시값

    @Test("표시 문구는 서버 값을 그대로 옮긴다 — 앱이 유형별 문구를 만들지 않는다")
    func carriesServerStringsVerbatim() throws {
        let dto = try decode(json(typeLabel: "서버가 정한 문구", targetName: "성수 브루잉"))
        let notification = dto.toDomain()

        #expect(notification.title == "서버가 정한 문구")
        #expect(notification.targetName == "성수 브루잉")
    }

    @Test("스킴 없는 썸네일 문자열은 버린다 — 상대 URL 로 성공해 엉뚱한 값이 이미지가 된다")
    func dropsThumbnailWithoutHTTPScheme() throws {
        let http = try decode(json(thumbnailUrl: "https://cdn.example.com/a.jpg"))
        let bare = try decode(json(thumbnailUrl: "orange"))

        #expect(http.toDomain().thumbnailURL == URL(string: "https://cdn.example.com/a.jpg"))
        #expect(bare.toDomain().thumbnailURL == nil)
    }

    // MARK: - 회귀 방지

    // 항목 하나에 키가 없다고 배열 전체가 실패하면 알림 탭이 통째로 죽는다.
    @Test("표시 문구가 빠진 항목이 섞여도 페이지 전체가 디코딩된다")
    func missingDisplayStringsDoNotKillThePage() throws {
        let list = "[\(json()),\(json(id: "n2", typeLabel: nil, targetName: nil))]"

        let dtos = try decodeList(list)

        #expect(dtos.count == 2)
        #expect(dtos[1].toDomain().title == "")
        #expect(dtos[1].toDomain().targetName == "")
    }

    // 서버는 소수점 이하 초를 붙여 보낸다. `Date(_:strategy: .iso8601)` 은 iOS 26 미만에서 그걸
    // 거부해 전부 epoch 로 떨어뜨린다(APIDecoder 주석의 실측) — 기대값을 파서로 만들면 그 회귀를
    // 못 잡으므로 여기서는 초 단위 숫자로 직접 적는다.
    @Test("소수점 이하 초가 붙은 createdAt 이 정확히 파싱된다")
    func parsesFractionalSecondTimestamps() throws {
        let dto = try decode(json(createdAt: "2026-09-01T12:00:00.566Z"))

        let expected = Date(timeIntervalSince1970: 1_788_264_000.566)
        #expect(abs(dto.toDomain().createdAt.timeIntervalSince(expected)) < 0.001)
    }

    @Test("소수점이 없는 createdAt 도 그대로 파싱된다")
    func parsesPlainTimestamps() throws {
        let dto = try decode(json(createdAt: "2026-09-01T12:00:00Z"))

        #expect(dto.toDomain().createdAt == Date(timeIntervalSince1970: 1_788_264_000))
    }
}
