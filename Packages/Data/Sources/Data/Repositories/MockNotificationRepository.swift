import Foundation
import Domain
import Networking

/// 백엔드 미연결 단계용 `NotificationRepository` 구현.
/// 서버의 `type`·`payload` 스키마가 확정되지 않아(둘 다 비어 있다) 붙일 대상이 없다.
///
/// 네트워크 대신 하드코딩 JSON 을 쓰되, **네트워크 구현이 설 자리와 같은 모양으로 조립한다**
/// (`MockRoomRepository` 선례) — `Networking.Page` 한 장을 만들어 `toDomain(request:_:)` 경계
/// 매핑에 태운다. 실 구현은 그 한 장을 `client.requestPage(...)` 에서 받아오는 것만 달라진다
/// (`Packages/Networking/Docs/AddingAPI.md`), 그래서 `NotificationDTO.toDomain()` 과 경계 매핑은
/// 교체 후에도 그대로 재사용된다.
///
/// 선례와 다른 점은 JSON 을 주입받는 것 하나다 — PR4 의 화면 상태 중 빈 상태를 소스 수정 없이
/// 띄우려면 항목이 없는 응답을 만들 수 있어야 한다.
public final class MockNotificationRepository: NotificationRepository {
    private let json: String

    public init(json: String = MockNotificationRepository.mockJSON) {
        self.json = json
    }

    /// 빈 상태 화면을 띄우기 위한 응답. PR4 프리뷰·수동 확인이 이걸 주입한다.
    public static let emptyJSON = #"{"data":[],"pagination":{"page":0,"hasNext":false}}"#

    public func notifications() async throws -> Domain.Page<AppNotification> {
        try await notifications(.first(pageSize: PageRequest.defaultPageSize))
    }

    // `Page` 는 Domain 과 Networking 양쪽에 있어 한정자 없이는 모호하다 — 경계를 넘나드는 파일에서는
    // 어느 쪽 Page 인지 이름으로 드러낸다.
    public func notifications(_ request: PageRequest) async throws -> Domain.Page<AppNotification> {
        // `request.page`·`request.pageSize` 로 만드는 슬라이스 구간이 배열 음수 인덱스·정수
        // 오버플로 트랩으로 이어질 수 있다 — 전부 do/catch 밖에서 일어나는 크래시라 슬라이스 전에
        // 안전하게 계산해 실패시킨다. 0 으로 클램프하지 않는 이유: 클램프하면 "요청한 장과 다른
        // 장이 조용히 돌아오는" 오류가 되어 더 진단하기 어렵다 — 같은 DomainError 로 던진다.
        // 곱셈(start)과 덧셈(end) 둘 다 오버플로 지점이다 — 한쪽만 막으면 그 경계 바로 위 값이
        // 여전히 크래시한다(예: page·pageSize 곱은 안 넘치는데 그 결과 + pageSize 가 넘치는 경우).
        guard request.page >= 0 else { throw DomainError.notificationsFetchFailed }
        let (start, startOverflowed) = request.page.multipliedReportingOverflow(by: request.pageSize)
        guard !startOverflowed else { throw DomainError.notificationsFetchFailed }
        let (rawEnd, endOverflowed) = start.addingReportingOverflow(request.pageSize)
        guard !endOverflowed else { throw DomainError.notificationsFetchFailed }
        do {
            let all = try JSONDecoder().decode(MockNotificationsDTO.self, from: Data(json.utf8)).data
            let end = min(rawEnd, all.count)
            let slice = start < all.count ? Array(all[start..<end]) : []
            let page = Networking.Page(
                items: slice,
                pagination: Pagination(pageSize: request.pageSize, page: request.page, hasNext: end < all.count)
            )
            return page.toDomain(request: request) { $0.toDomain() }
        } catch {
            throw DomainError.notificationsFetchFailed
        }
    }

    /// 유형 6종 + 알 수 없는 type 1건(`notif-0007`, 첫 장 안). 21건 — 첫 장 20 + 다음 장 1.
    /// createdAt 내림차순. 장소 대상 3종(`duplicateSave`·`nearbyReminder`·`commentReminder`)에만
    /// `placeImageUrl` 을 실어 FR-012 의 두 썸네일 갈래를 재현한다. `saveError`·모르는 유형은
    /// payload 키 자체를 생략해 "옵셔널 필드가 없어도 디코딩은 성공한다" 를 목에서도 재현한다.
    ///
    /// `type` 문자열은 잠정이다(`NotificationDTO.mapType` 주석 참고) — 여기 쓴 값도 그 placeholder 다.
    public static let mockJSON = """
    {
      "data": [
        {
          "id": "notif-0001",
          "type": "duplicateSave",
          "createdAt": "2026-08-21T09:00:00Z",
          "payload": {
            "placeName": "연남동 스탠딩 커피",
            "placeImageUrl": "https://cdn.mino.app/places/0001.jpg",
            "placeId": "place-0001"
          }
        },
        {
          "id": "notif-0002",
          "type": "saveError",
          "createdAt": "2026-08-21T08:00:00Z"
        },
        {
          "id": "notif-0003",
          "type": "nearbyReminder",
          "createdAt": "2026-08-21T07:00:00Z",
          "payload": {
            "placeName": "을지로 골목집",
            "placeImageUrl": "https://cdn.mino.app/places/0003.jpg",
            "placeId": "place-0003"
          }
        },
        {
          "id": "notif-0004",
          "type": "commentReminder",
          "createdAt": "2026-08-21T06:00:00Z",
          "payload": {
            "placeName": "성수동 카페거리",
            "placeImageUrl": "https://cdn.mino.app/places/0004.jpg",
            "placeId": "place-0004"
          }
        },
        {
          "id": "notif-0005",
          "type": "memberJoined",
          "createdAt": "2026-08-21T05:00:00Z",
          "payload": {
            "roomName": "언젠가 가야지 방",
            "roomId": "room-0005",
            "participantName": "지은"
          }
        },
        {
          "id": "notif-0006",
          "type": "roomJoined",
          "createdAt": "2026-08-21T04:00:00Z",
          "payload": {
            "roomName": "주말 나들이",
            "roomId": "room-0006"
          }
        },
        {
          "id": "notif-0007",
          "type": "futureType",
          "createdAt": "2026-08-21T03:00:00Z"
        },
        {
          "id": "notif-0008",
          "type": "saveError",
          "createdAt": "2026-08-21T02:00:00Z"
        },
        {
          "id": "notif-0009",
          "type": "nearbyReminder",
          "createdAt": "2026-08-21T01:00:00Z",
          "payload": {
            "placeName": "성수동 카페거리",
            "placeImageUrl": "https://cdn.mino.app/places/0009.jpg",
            "placeId": "place-0009"
          }
        },
        {
          "id": "notif-0010",
          "type": "commentReminder",
          "createdAt": "2026-08-21T00:00:00Z",
          "payload": {
            "placeName": "합정 브런치",
            "placeImageUrl": "https://cdn.mino.app/places/0010.jpg",
            "placeId": "place-0010"
          }
        },
        {
          "id": "notif-0011",
          "type": "memberJoined",
          "createdAt": "2026-08-20T23:00:00Z",
          "payload": {
            "roomName": "맛집 탐방",
            "roomId": "room-0011",
            "participantName": "서연"
          }
        },
        {
          "id": "notif-0012",
          "type": "roomJoined",
          "createdAt": "2026-08-20T22:00:00Z",
          "payload": {
            "roomName": "우리 동네 맛집",
            "roomId": "room-0012"
          }
        },
        {
          "id": "notif-0013",
          "type": "duplicateSave",
          "createdAt": "2026-08-20T21:00:00Z",
          "payload": {
            "placeName": "을지로 골목집",
            "placeImageUrl": "https://cdn.mino.app/places/0013.jpg",
            "placeId": "place-0013"
          }
        },
        {
          "id": "notif-0014",
          "type": "saveError",
          "createdAt": "2026-08-20T20:00:00Z"
        },
        {
          "id": "notif-0015",
          "type": "nearbyReminder",
          "createdAt": "2026-08-20T19:00:00Z",
          "payload": {
            "placeName": "합정 브런치",
            "placeImageUrl": "https://cdn.mino.app/places/0015.jpg",
            "placeId": "place-0015"
          }
        },
        {
          "id": "notif-0016",
          "type": "commentReminder",
          "createdAt": "2026-08-20T18:00:00Z",
          "payload": {
            "placeName": "연남동 스탠딩 커피",
            "placeImageUrl": "https://cdn.mino.app/places/0016.jpg",
            "placeId": "place-0016"
          }
        },
        {
          "id": "notif-0017",
          "type": "memberJoined",
          "createdAt": "2026-08-20T17:00:00Z",
          "payload": {
            "roomName": "언젠가 가야지 방",
            "roomId": "room-0017",
            "participantName": "지은"
          }
        },
        {
          "id": "notif-0018",
          "type": "roomJoined",
          "createdAt": "2026-08-20T16:00:00Z",
          "payload": {
            "roomName": "주말 나들이",
            "roomId": "room-0018"
          }
        },
        {
          "id": "notif-0019",
          "type": "duplicateSave",
          "createdAt": "2026-08-20T15:00:00Z",
          "payload": {
            "placeName": "성수동 카페거리",
            "placeImageUrl": "https://cdn.mino.app/places/0019.jpg",
            "placeId": "place-0019"
          }
        },
        {
          "id": "notif-0020",
          "type": "saveError",
          "createdAt": "2026-08-20T14:00:00Z"
        },
        {
          "id": "notif-0021",
          "type": "nearbyReminder",
          "createdAt": "2026-08-20T13:00:00Z",
          "payload": {
            "placeName": "연남동 스탠딩 커피",
            "placeImageUrl": "https://cdn.mino.app/places/0021.jpg",
            "placeId": "place-0021"
          }
        }
      ]
    }
    """
}

/// `mockJSON`/`emptyJSON` 의 `data` 배열만 꺼내는 디코드 전용 래퍼. 서버 응답 envelope
/// (`Networking.APIEnvelope`)과 다르다 — 목은 페이지 하나가 아니라 **전체 항목**을 담고, 실제
/// 페이지 슬라이싱은 `MockNotificationRepository.notifications(_:)` 가 요청값 기준으로 한다.
/// `pagination` 키가 함께 와도(`emptyJSON`) 여기서 쓰지 않으니 무시된다.
private struct MockNotificationsDTO: Decodable {
    let data: [NotificationDTO]
}
