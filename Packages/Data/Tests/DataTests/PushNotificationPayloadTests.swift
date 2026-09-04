import Domain
import Testing
@testable import Data

/// 푸시 `data` → 이동 대상 매핑을 고정한다. 유형별 실제 payload(백엔드 문서)를 그대로 넣는다.
@Suite("PushNotificationPayload")
struct PushNotificationPayloadTests {
    @Test("장소 알림 3종은 pinId 로 장소 상세를 연다")
    func placeTypes() {
        for type in ["PIN_DUPLICATED", "TOP_COMMENTED_PLACE", "NEARBY_PLACE"] {
            let destination = PushNotificationPayload.destination(from: [
                "type": type,
                "placeId": "place-1",
                "pinId": "pin-1",
                "title": "어니언 성수",
                "body": "근처에 저장한 장소가 있어요",
                "imageUrl": "https://cdn.example/place.jpg",
            ])
            #expect(destination == .place(pinID: PinID("pin-1")))
        }
    }

    // 목록 API 와 같은 규칙이다(f15b5ab) — placeId 는 장소 마스터 id 라 `GET /pins/{id}` 에 넣으면
    // 404 다. 잘못된 요청을 보내느니 알림 탭에서 끝내는 편이 낫다.
    @Test("placeId 만 오면 placeId 로 폴백하지 않고 unresolved 다")
    func placeWithoutPinID_isUnresolved() {
        let destination = PushNotificationPayload.destination(from: [
            "type": "PIN_DUPLICATED",
            "placeId": "place-1",
        ])
        #expect(destination == .unresolved)
    }

    @Test("방 알림 2종은 roomId 로 방 상세를 연다")
    func roomTypes() {
        for type in ["ROOM_MEMBER_JOINED", "ROOM_JOINED_SELF"] {
            let destination = PushNotificationPayload.destination(from: [
                "type": type,
                "roomId": "room-1",
                "title": "성수 맛집 탐방",
                "body": "지연님이 들어왔어요",
            ])
            #expect(destination == .room(roomID: "room-1"))
        }
    }

    @Test("저장 실패는 식별자 없이 저장 오류 안내로 간다")
    func saveFailed() {
        let destination = PushNotificationPayload.destination(from: [
            "type": "SAVE_FAILED",
            "title": "잠시 후 다시 시도해주세요",
            "body": "장소를 저장하지 못했어요.",
        ])
        #expect(destination == .saveError)
    }

    // 푸시로만 오고 목록에는 없는 유형이다(FR-019). 식별자가 없어 갈 곳이 없는 게 정상이다.
    @Test("주변 장소 대표 푸시는 갈 곳이 없어 unresolved 다")
    func nearbySummary() {
        let destination = PushNotificationPayload.destination(from: [
            "type": "NEARBY_PLACE_SUMMARY",
            "title": "근처에 저장한 곳 3개가 있어요",
            "body": "반경 3km",
        ])
        #expect(destination == .unresolved)
    }

    // 유형을 먼저 보고 그 유형이 요구하는 키만 읽는다 — 섞여 와도 엉뚱한 곳으로 가지 않는다.
    @Test("방 알림에 pinId 가 섞여 와도 장소로 새지 않는다")
    func roomTypeIgnoresPinID() {
        let destination = PushNotificationPayload.destination(from: [
            "type": "ROOM_JOINED_SELF",
            "roomId": "room-1",
            "pinId": "pin-1",
        ])
        #expect(destination == .room(roomID: "room-1"))
    }

    @Test("모르는 유형과 type 누락은 unresolved 다")
    func unknownOrMissingType() {
        #expect(PushNotificationPayload.destination(from: ["type": "WHAT_IS_THIS", "pinId": "pin-1"]) == .unresolved)
        #expect(PushNotificationPayload.destination(from: ["pinId": "pin-1"]) == .unresolved)
    }

    // APNs 가 얹는 키들 사이에서도 우리 키만 골라내는지.
    @Test("aps·gcm 키가 섞인 실제 userInfo 에서도 대상을 찾는다")
    func ignoresAPNsKeys() {
        let destination = PushNotificationPayload.destination(from: [
            "aps": ["alert": ["title": "제목", "body": "내용"], "mutable-content": 1],
            "gcm.message_id": "0:1788172628762123%a1b2c3d4",
            "google.c.fid": "abc",
            "from": "1035469437363",
            "collapse_key": "com.mashup.teamMino",
            "type": "NEARBY_PLACE",
            "placeId": "place-1",
            "pinId": "pin-1",
        ])
        #expect(destination == .place(pinID: PinID("pin-1")))
    }

    // 서버가 값을 비워 보내는 경우. 공백뿐인 id 로 조회를 나가면 404 다.
    @Test("공백뿐인 식별자는 없는 것으로 본다")
    func blankIdentifier() {
        #expect(PushNotificationPayload.destination(from: ["type": "NEARBY_PLACE", "pinId": "  "]) == .unresolved)
    }
}
