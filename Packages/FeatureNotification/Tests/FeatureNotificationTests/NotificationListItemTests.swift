import Foundation
import Testing
import Domain
@testable import FeatureNotification

// FR-004 유형 6종 문구 매핑 + FR-012 썸네일 갈래(imageURL 유무).
struct NotificationListItemTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func notification(_ type: NotificationType, _ payload: NotificationPayload) -> AppNotification {
        AppNotification(id: NotificationID("n0"), type: type, payload: payload, createdAt: now)
    }

    @Test("중복 저장 — 이미 저장해둔 곳이에요 / 장소명 / .place 썸네일")
    func duplicateSave() {
        let item = NotificationListItem(
            from: notification(.duplicateSave, .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: nil)),
            now: now
        )
        #expect(item.title == "이미 저장해둔 곳이에요")
        #expect(item.subtitle == "연남동 스탠딩 커피")
        #expect(item.destination == .place)
    }

    @Test("저장 오류 — 장소를 저장하지 못했어요. / 잠시 후 다시 시도해주세요 / .icon 썸네일")
    func saveError() {
        let item = NotificationListItem(from: notification(.saveError, .saveError), now: now)
        #expect(item.title == "장소를 저장하지 못했어요.")
        #expect(item.subtitle == "잠시 후 다시 시도해주세요")
        #expect(item.imageURL == nil)
        #expect(item.destination == .saveError)
    }

    @Test("위치 기반 리마인드 — 근처에 저장한 장소가 있어요 / 장소명")
    func nearbyReminder() {
        let item = NotificationListItem(
            from: notification(.nearbyReminder, .place(name: "강남역 스타벅스", imageURL: nil, placeID: nil)),
            now: now
        )
        #expect(item.title == "근처에 저장한 장소가 있어요")
        #expect(item.subtitle == "강남역 스타벅스")
        #expect(item.destination == .place)
    }

    @Test("코멘트 기반 리마인드 — 코멘트가 제일 많이 달린 장소에요 / 장소명")
    func commentReminder() {
        let item = NotificationListItem(
            from: notification(.commentReminder, .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: nil)),
            now: now
        )
        #expect(item.title == "코멘트가 제일 많이 달린 장소에요")
        #expect(item.subtitle == "연남동 스탠딩 커피")
        #expect(item.destination == .place)
    }

    @Test("공동방 참가 ① — {참가자 이름}님이 들어왔어요 / 방 이름 / .icon 썸네일")
    func memberJoined() {
        let item = NotificationListItem(
            from: notification(.memberJoined, .room(name: "언젠가 가야지 방", roomID: nil, participantName: "지은")),
            now: now
        )
        #expect(item.title == "지은님이 들어왔어요")
        #expect(item.subtitle == "언젠가 가야지 방")
        #expect(item.imageURL == nil)
        #expect(item.destination == .room)
    }

    @Test("공동방 참가 ② — 방에 참가했어요 / 방 이름 / .icon 썸네일")
    func roomJoined() {
        let item = NotificationListItem(
            from: notification(.roomJoined, .room(name: "언젠가 가야지 방", roomID: nil, participantName: nil)),
            now: now
        )
        #expect(item.title == "방에 참가했어요")
        #expect(item.subtitle == "언젠가 가야지 방")
        #expect(item.imageURL == nil)
        #expect(item.destination == .room)
    }

    @Test("장소 대상 알림은 payload 의 imageURL 을 그대로 옮긴다(FR-012 — 썸네일 갈래는 View 계층 몫)")
    func imageURLPassthrough() {
        let url = URL(string: "https://example.com/p.jpg")
        let withImage = NotificationListItem(
            from: notification(.duplicateSave, .place(name: "연남동 스탠딩 커피", imageURL: url, placeID: nil)),
            now: now
        )
        let withoutImage = NotificationListItem(
            from: notification(.duplicateSave, .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: nil)),
            now: now
        )
        #expect(withImage.imageURL == url)
        #expect(withoutImage.imageURL == nil)
    }
}
