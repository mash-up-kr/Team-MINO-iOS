import Foundation
import Testing
import Domain
@testable import FeatureNotification

/// 표시 모델 매핑. **문구 단언이 없다** — 유형별 문구는 서버가 `typeLabel` 로 완성해서 주므로
/// 앱이 만들지 않는다(그 매핑을 검증하던 6종 테스트는 삭제됐다). 여기 남은 계약은 둘이다:
/// 서버 값을 손대지 않고 옮기는가, 그리고 목적지 식별자가 유실되지 않는가.
struct NotificationListItemTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func notification(
        title: String = "이미 저장해둔 곳이에요",
        targetName: String = "패스트리 순간",
        thumbnailURL: URL? = nil,
        destination: NotificationDestination
    ) -> AppNotification {
        AppNotification(
            id: NotificationID("n0"),
            type: .duplicateSave,
            title: title,
            targetName: targetName,
            thumbnailURL: thumbnailURL,
            destination: destination,
            createdAt: now
        )
    }

    @Test("서버 문구를 그대로 옮긴다 — 앱이 유형별 문구를 만들지 않는다")
    func carriesServerStringsVerbatim() {
        let item = NotificationListItem(
            from: notification(title: "새로 생긴 문구", targetName: "성수 브루잉", destination: .saveError),
            now: now
        )

        #expect(item.title == "새로 생긴 문구")
        #expect(item.subtitle == "성수 브루잉")
    }

    @Test("썸네일은 서버 값을 그대로 옮긴다(FR-012 — 썸네일 갈래는 View 계층 몫)")
    func imageURLPassthrough() {
        let url = URL(string: "https://example.com/p.jpg")

        let withImage = NotificationListItem(
            from: notification(thumbnailURL: url, destination: .saveError), now: now
        )
        let withoutImage = NotificationListItem(
            from: notification(thumbnailURL: nil, destination: .saveError), now: now
        )

        #expect(withImage.imageURL == url)
        #expect(withoutImage.imageURL == nil)
    }

    // 표시 모델이 식별자를 떨어뜨리면 셀은 멀쩡해 보이는데 탭만 조용히 안 먹는다.
    @Test("목적지 식별자가 표시 모델까지 살아서 온다")
    func carriesDestinationIdentifiers() {
        let place = NotificationListItem(
            from: notification(destination: .place(pinID: PinID("pin-1"))), now: now
        )
        let room = NotificationListItem(
            from: notification(destination: .room(roomID: "room-1")), now: now
        )
        let saveError = NotificationListItem(from: notification(destination: .saveError), now: now)
        let unresolved = NotificationListItem(from: notification(destination: .unresolved), now: now)

        #expect(place.destination == .place(pinID: PinID("pin-1")))
        #expect(room.destination == .room(roomID: "room-1"))
        #expect(saveError.destination == .saveError)
        #expect(unresolved.destination == .unresolved)
    }
}
