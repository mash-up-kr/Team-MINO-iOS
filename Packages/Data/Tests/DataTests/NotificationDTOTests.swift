import Foundation
import Testing
import Domain
@testable import Data

/// `NotificationDTO.toDomain()` 경계 매핑 순수 로직 테스트.
/// DTO 는 internal 이라 이 파일(Data 테스트 타깃)에서만 만들 수 있다.
///
/// 이 스위트가 **`type` 과 `payload` 의 조합 규칙을 강제하는 유일한 장치**다 — 도메인 타입은
/// 어긋난 조합을 막지 못하고, `precondition` 도 두지 않기로 했다(서버 데이터로 앱을 죽이지 않는다).
@Suite("NotificationDTO → AppNotification 매핑")
struct NotificationDTOTests {
    private func makeDTO(
        id: String = "n1",
        type: String = "duplicateSave",
        payload: NotificationPayloadDTO? = nil,
        readAt: String? = nil,
        createdAt: String = "2026-08-21T09:00:00Z"
    ) -> NotificationDTO {
        NotificationDTO(id: id, type: type, payload: payload, readAt: readAt, createdAt: createdAt)
    }

    private func makePayloadDTO(
        placeName: String? = nil,
        placeImageUrl: String? = nil,
        placeId: String? = nil,
        roomName: String? = nil,
        roomId: String? = nil,
        participantName: String? = nil
    ) -> NotificationPayloadDTO {
        NotificationPayloadDTO(
            placeName: placeName, placeImageUrl: placeImageUrl, placeId: placeId,
            roomName: roomName, roomId: roomId, participantName: participantName
        )
    }

    @Test("중복 저장은 장소 이름과 장소 식별자를 실어 나른다")
    func mapsDuplicateSaveToPlace() {
        let dto = makeDTO(type: "duplicateSave", payload: makePayloadDTO(placeName: "연남동 스탠딩 커피", placeId: "place-1"))

        let notification = dto.toDomain()

        #expect(notification.type == .duplicateSave)
        #expect(notification.payload == .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: "place-1"))
    }

    @Test("저장 오류는 실어 나를 값이 없다")
    func mapsSaveErrorWithoutValues() {
        let dto = makeDTO(type: "saveError", payload: nil)

        let notification = dto.toDomain()

        #expect(notification.type == .saveError)
        #expect(notification.payload == .saveError)
    }

    @Test("위치 리마인드 단건은 장소 이름을 싣는다")
    func mapsNearbyReminderToPlace() {
        let dto = makeDTO(type: "nearbyReminder", payload: makePayloadDTO(placeName: "강남역 스타벅스"))

        let notification = dto.toDomain()

        #expect(notification.type == .nearbyReminder)
        #expect(notification.payload == .place(name: "강남역 스타벅스", imageURL: nil, placeID: nil))
    }

    @Test("코멘트 리마인드는 장소 이름을 싣는다")
    func mapsCommentReminderToPlace() {
        let dto = makeDTO(type: "commentReminder", payload: makePayloadDTO(placeName: "성수동 카페거리"))

        let notification = dto.toDomain()

        #expect(notification.type == .commentReminder)
        #expect(notification.payload == .place(name: "성수동 카페거리", imageURL: nil, placeID: nil))
    }

    @Test("장소 이미지 주소를 그대로 실어 나른다")
    func carriesPlaceImageURL() {
        let dto = makeDTO(
            type: "duplicateSave",
            payload: makePayloadDTO(placeName: "연남동 스탠딩 커피", placeImageUrl: "https://cdn.mino.app/places/1.jpg")
        )

        let notification = dto.toDomain()

        guard case let .place(_, imageURL, _) = notification.payload else {
            Issue.record("payload 가 .place 가 아니다: \(notification.payload)")
            return
        }
        #expect(imageURL == URL(string: "https://cdn.mino.app/places/1.jpg"))
    }

    @Test("이미지 주소가 주소 꼴이 아니면 없는 것으로 둔다")
    func dropsMalformedPlaceImageURL() {
        let dto = makeDTO(
            type: "duplicateSave",
            payload: makePayloadDTO(placeName: "연남동 스탠딩 커피", placeImageUrl: "완전히 깨진 주소")
        )

        let notification = dto.toDomain()

        guard case let .place(name, imageURL, _) = notification.payload else {
            Issue.record("payload 가 .place 가 아니다: \(notification.payload)")
            return
        }
        #expect(name == "연남동 스탠딩 커피")
        #expect(imageURL == nil)
    }

    @Test("http(s) 가 아닌 스킴은 이미지 주소로 받아들이지 않는다")
    func dropsNonHTTPImageURLScheme() {
        let dto = makeDTO(
            type: "duplicateSave",
            payload: makePayloadDTO(placeName: "연남동 스탠딩 커피", placeImageUrl: "javascript:alert(1)")
        )

        let notification = dto.toDomain()

        guard case let .place(_, imageURL, _) = notification.payload else {
            Issue.record("payload 가 .place 가 아니다: \(notification.payload)")
            return
        }
        #expect(imageURL == nil)
    }

    @Test("타인 참가 알림은 참가자 이름과 방 이름을 함께 싣는다")
    func mapsMemberJoinedWithParticipantName() {
        let dto = makeDTO(
            type: "memberJoined",
            payload: makePayloadDTO(roomName: "언젠가 가야지 방", roomId: "room-1", participantName: "지은")
        )

        let notification = dto.toDomain()

        #expect(notification.type == .memberJoined)
        #expect(notification.payload == .room(name: "언젠가 가야지 방", roomID: "room-1", participantName: "지은"))
    }

    @Test("본인 참가 알림에는 참가자 이름이 없다")
    func mapsRoomJoinedWithoutParticipantName() {
        let dto = makeDTO(type: "roomJoined", payload: makePayloadDTO(roomName: "주말 나들이", roomId: "room-2"))

        let notification = dto.toDomain()

        #expect(notification.type == .roomJoined)
        #expect(notification.payload == .room(name: "주말 나들이", roomID: "room-2", participantName: nil))
    }

    @Test("알 수 없는 종류는 원문을 잃지 않는다")
    func preservesRawStringForUnknownType() {
        let dto = makeDTO(type: "한번도_본_적_없는_값")

        let notification = dto.toDomain()

        #expect(notification.type == .unknown(raw: "한번도_본_적_없는_값"))
    }

    @Test("알 수 없는 종류여도 나머지 필드는 그대로 옮겨진다")
    func keepsOtherFieldsWhenTypeIsUnknown() {
        let dto = makeDTO(id: "n42", type: "미확정타입", createdAt: "2026-08-21T09:00:00Z")

        let notification = dto.toDomain()

        #expect(notification.id == NotificationID("n42"))
        #expect(notification.createdAt == parseISO8601("2026-08-21T09:00:00Z"))
        #expect(notification.payload == .unresolved)
    }

    @Test("종류가 요구하는 값이 없으면 해석하지 못한 것으로 둔다")
    func fallsBackToUnresolvedWhenRequiredFieldMissing() {
        let dto = makeDTO(type: "duplicateSave", payload: nil)

        let notification = dto.toDomain()

        #expect(notification.payload == .unresolved)
    }

    @Test("payload 키가 통째로 없어도 디코딩은 성공한다")
    func decodesWhenPayloadKeyIsAbsent() throws {
        let json = #"{"id":"n1","type":"duplicateSave","createdAt":"2026-08-21T09:00:00Z"}"#
        let dto = try JSONDecoder().decode(NotificationDTO.self, from: Data(json.utf8))

        let notification = dto.toDomain()

        #expect(notification.payload == .unresolved)
    }

    @Test("날짜를 못 읽으면 epoch 로 둔다")
    func fallsBackToEpochWhenDateIsUnreadable() {
        let dto = makeDTO(createdAt: "깨진값")

        let notification = dto.toDomain()

        #expect(notification.createdAt == Date(timeIntervalSince1970: 0))
    }

    @Test("서버가 보낸 읽음 시각은 도메인까지 올라오지 않는다")
    func doesNotCarryReadAtIntoDomain() throws {
        let json = #"{"id":"n1","type":"duplicateSave","readAt":"2026-08-21T10:00:00Z","createdAt":"2026-08-21T09:00:00Z"}"#
        let dto = try JSONDecoder().decode(NotificationDTO.self, from: Data(json.utf8))

        #expect(dto.readAt == "2026-08-21T10:00:00Z")
        // AppNotification 에는 readAt 을 담는 자리가 없다 — 아래 매핑 결과가 컴파일되는 것 자체가 그 증거다.
        let notification = dto.toDomain()
        #expect(notification.id == NotificationID("n1"))
    }

    @Test("종류와 무관한 필드가 섞여 와도 종류가 요구하는 값만 읽는다")
    func readsOnlyFieldsTheTypeRequiresWhenPayloadIsPolluted() {
        let dto = makeDTO(
            type: "memberJoined",
            payload: makePayloadDTO(
                placeName: "엉뚱하게 섞인 장소",
                placeImageUrl: "https://cdn.mino.app/places/x.jpg",
                roomName: "언젠가 가야지 방",
                roomId: "room-1",
                participantName: "지은"
            )
        )

        let notification = dto.toDomain()

        #expect(notification.payload == .room(name: "언젠가 가야지 방", roomID: "room-1", participantName: "지은"))
    }

    @Test("역방향으로 섞여 와도 마찬가지다")
    func readsOnlyFieldsTheTypeRequiresInReverse() {
        let dto = makeDTO(
            type: "duplicateSave",
            payload: makePayloadDTO(
                placeName: "연남동 스탠딩 커피",
                placeId: "place-1",
                roomName: "엉뚱하게 섞인 방",
                roomId: "room-x",
                participantName: "엉뚱한 사람"
            )
        )

        let notification = dto.toDomain()

        #expect(notification.payload == .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: "place-1"))
    }

    @Test("타인 참가 알림에 참가자 이름이 없으면 해석하지 못한 것으로 둔다")
    func requiresParticipantNameForMemberJoined() {
        let dto = makeDTO(type: "memberJoined", payload: makePayloadDTO(roomName: "언젠가 가야지 방", roomId: "room-1"))

        let notification = dto.toDomain()

        #expect(notification.payload == .unresolved)
    }

    @Test("본인 참가 알림에 참가자 이름이 실려 와도 읽지 않는다")
    func roomJoinedIgnoresParticipantNameEvenWhenPresent() {
        // memberJoined ↔ roomJoined 교차 오염의 반대 방향. 이 픽스처가 없으면
        // `participantName: dto?.participantName` 처럼 항상 읽는 구현도 통과해, 두 참가
        // 유형이 payload 로는 구별되지 않게 된다.
        let dto = makeDTO(
            type: "roomJoined",
            payload: makePayloadDTO(roomName: "주말 나들이", roomId: "room-2", participantName: "엉뚱하게 섞인 이름")
        )

        let notification = dto.toDomain()

        #expect(notification.payload == .room(name: "주말 나들이", roomID: "room-2", participantName: nil))
    }

    @Test("공백뿐인 이름은 없는 것으로 둔다")
    func blankNameFallsBackToUnresolved() {
        let dto = makeDTO(type: "duplicateSave", payload: makePayloadDTO(placeName: "   "))

        let notification = dto.toDomain()

        #expect(notification.payload == .unresolved)
    }
}
