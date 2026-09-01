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
            let all = try APIDecoder.make().decode(MockNotificationsDTO.self, from: Data(json.utf8)).data
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

    /// 확정 유형 6종 + 앱이 모르는 type 1건(`notif-0007`, 첫 장 안). 21건 — 첫 장 20 + 다음 장 1.
    /// createdAt 내림차순. 장소 대상 3종에만 `thumbnailUrl` 을 실어 FR-012 의 두 썸네일 갈래를
    /// 재현하고, `SAVE_FAILED` 는 payload 키 자체를 생략해 "이동 대상 없음" 을 목에서도 재현한다.
    public static let mockJSON = """
    {
      "data": [
        {
          "id": "notif-0001",
          "type": "PIN_DUPLICATED",
          "typeLabel": "이미 저장해둔 곳이에요",
          "createdAt": "2026-08-21T20:00:00.000Z",
          "targetName": "패스트리 순간",
          "thumbnailUrl": "https://cdn.mino.app/places/0001.jpg",
          "payload": {
            "placeId": "pin-0001"
          }
        },
        {
          "id": "notif-0002",
          "type": "SAVE_FAILED",
          "typeLabel": "장소를 저장하지 못했어요",
          "createdAt": "2026-08-21T19:00:00.000Z",
          "targetName": "인스타그램 게시물"
        },
        {
          "id": "notif-0003",
          "type": "NEARBY_PLACE",
          "typeLabel": "근처에 저장한 장소가 있어요",
          "createdAt": "2026-08-21T18:00:00.000Z",
          "targetName": "망원 국수집",
          "thumbnailUrl": "https://cdn.mino.app/places/0003.jpg",
          "payload": {
            "placeId": "pin-0003"
          }
        },
        {
          "id": "notif-0004",
          "type": "TOP_COMMENTED_PLACE",
          "typeLabel": "코멘트가 제일 많이 달린 장소에요",
          "createdAt": "2026-08-21T17:00:00.000Z",
          "targetName": "해방촌 루프탑",
          "thumbnailUrl": "https://cdn.mino.app/places/0004.jpg",
          "payload": {
            "placeId": "pin-0004"
          }
        },
        {
          "id": "notif-0005",
          "type": "ROOM_MEMBER_JOINED",
          "typeLabel": "새 멤버가 들어왔어요",
          "createdAt": "2026-08-21T16:00:00.000Z",
          "targetName": "주말 산책",
          "payload": {
            "roomId": "room-0005"
          }
        },
        {
          "id": "notif-0006",
          "type": "ROOM_JOINED_SELF",
          "typeLabel": "방에 참가했어요",
          "createdAt": "2026-08-21T15:00:00.000Z",
          "targetName": "맛집 탐방",
          "payload": {
            "roomId": "room-0006"
          }
        },
        {
          "id": "notif-0007",
          "type": "REALLY_NEW_KIND",
          "typeLabel": "새로 생긴 알림",
          "targetName": "무언가",
          "createdAt": "2026-08-21T14:00:00.000Z"
        },
        {
          "id": "notif-0008",
          "type": "SAVE_FAILED",
          "typeLabel": "장소를 저장하지 못했어요",
          "createdAt": "2026-08-21T13:00:00.000Z",
          "targetName": "인스타그램 게시물"
        },
        {
          "id": "notif-0009",
          "type": "NEARBY_PLACE",
          "typeLabel": "근처에 저장한 장소가 있어요",
          "createdAt": "2026-08-21T12:00:00.000Z",
          "targetName": "해방촌 루프탑",
          "thumbnailUrl": "https://cdn.mino.app/places/0009.jpg",
          "payload": {
            "placeId": "pin-0009"
          }
        },
        {
          "id": "notif-0010",
          "type": "TOP_COMMENTED_PLACE",
          "typeLabel": "코멘트가 제일 많이 달린 장소에요",
          "createdAt": "2026-08-21T11:00:00.000Z",
          "targetName": "연남동 스탠딩 커피",
          "thumbnailUrl": "https://cdn.mino.app/places/0010.jpg",
          "payload": {
            "placeId": "pin-0010"
          }
        },
        {
          "id": "notif-0011",
          "type": "ROOM_MEMBER_JOINED",
          "typeLabel": "새 멤버가 들어왔어요",
          "createdAt": "2026-08-21T10:00:00.000Z",
          "targetName": "주말 산책",
          "payload": {
            "roomId": "room-0011"
          }
        },
        {
          "id": "notif-0012",
          "type": "ROOM_JOINED_SELF",
          "typeLabel": "방에 참가했어요",
          "createdAt": "2026-08-21T09:00:00.000Z",
          "targetName": "맛집 탐방",
          "payload": {
            "roomId": "room-0012"
          }
        },
        {
          "id": "notif-0013",
          "type": "PIN_DUPLICATED",
          "typeLabel": "이미 저장해둔 곳이에요",
          "createdAt": "2026-08-21T08:00:00.000Z",
          "targetName": "망원 국수집",
          "thumbnailUrl": "https://cdn.mino.app/places/0013.jpg",
          "payload": {
            "placeId": "pin-0013"
          }
        },
        {
          "id": "notif-0014",
          "type": "SAVE_FAILED",
          "typeLabel": "장소를 저장하지 못했어요",
          "createdAt": "2026-08-21T07:00:00.000Z",
          "targetName": "인스타그램 게시물"
        },
        {
          "id": "notif-0015",
          "type": "NEARBY_PLACE",
          "typeLabel": "근처에 저장한 장소가 있어요",
          "createdAt": "2026-08-21T06:00:00.000Z",
          "targetName": "연남동 스탠딩 커피",
          "thumbnailUrl": "https://cdn.mino.app/places/0015.jpg",
          "payload": {
            "placeId": "pin-0015"
          }
        },
        {
          "id": "notif-0016",
          "type": "TOP_COMMENTED_PLACE",
          "typeLabel": "코멘트가 제일 많이 달린 장소에요",
          "createdAt": "2026-08-21T05:00:00.000Z",
          "targetName": "패스트리 순간",
          "thumbnailUrl": "https://cdn.mino.app/places/0016.jpg",
          "payload": {
            "placeId": "pin-0016"
          }
        },
        {
          "id": "notif-0017",
          "type": "ROOM_MEMBER_JOINED",
          "typeLabel": "새 멤버가 들어왔어요",
          "createdAt": "2026-08-21T04:00:00.000Z",
          "targetName": "주말 산책",
          "payload": {
            "roomId": "room-0017"
          }
        },
        {
          "id": "notif-0018",
          "type": "ROOM_JOINED_SELF",
          "typeLabel": "방에 참가했어요",
          "createdAt": "2026-08-21T03:00:00.000Z",
          "targetName": "맛집 탐방",
          "payload": {
            "roomId": "room-0018"
          }
        },
        {
          "id": "notif-0019",
          "type": "PIN_DUPLICATED",
          "typeLabel": "이미 저장해둔 곳이에요",
          "createdAt": "2026-08-21T02:00:00.000Z",
          "targetName": "해방촌 루프탑",
          "thumbnailUrl": "https://cdn.mino.app/places/0019.jpg",
          "payload": {
            "placeId": "pin-0019"
          }
        },
        {
          "id": "notif-0020",
          "type": "SAVE_FAILED",
          "typeLabel": "장소를 저장하지 못했어요",
          "createdAt": "2026-08-21T01:00:00.000Z",
          "targetName": "인스타그램 게시물"
        },
        {
          "id": "notif-0021",
          "type": "NEARBY_PLACE",
          "typeLabel": "근처에 저장한 장소가 있어요",
          "createdAt": "2026-08-21T00:00:00.000Z",
          "targetName": "패스트리 순간",
          "thumbnailUrl": "https://cdn.mino.app/places/0021.jpg",
          "payload": {
            "placeId": "pin-0021"
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
