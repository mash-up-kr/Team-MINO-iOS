import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 저장한 장소 조회의 계약을 고정한다 — 어떤 경로·쿼리로 나가고, 응답이 어떤 핀으로 매핑되며,
/// 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("PinRepositoryImpl")
struct PinRepositoryImplTests {
    /// 스웨거(`GET /api/v1/rooms/{roomId}/cards`) 200 응답 그대로 — `data` 는 배열이 아니라
    /// `{ room, cards }` 객체다. 쓰지 않는 `room` 과 `place.provider` 같은 키도 실제 응답처럼
    /// 남겨 둔다: 안 읽는 키가 늘어도 덱이 깨지지 않아야 한다.
    private static let cardsJSON = """
    {
      "room": { "id": "room-1", "type": "shared", "name": "맛집 탐방", "color": "red" },
      "cards": [
        {
          "id": "pin-1", "roomId": "room-1",
          "place": { "id": "place-1", "provider": "kakao", "providerPlaceId": "1",
                     "name": "레이어스튜디오", "address": "서울 성동구 상원4길 10",
                     "city": "서울", "district": "성동구",
                     "lat": 37.5443, "lng": 127.0557, "category": "카페", "phone": null,
                     "mapUrl": "https://map.kakao.com/p/1" },
          "images": ["https://cdn.example.com/a.jpg", ""],
          "createdBy": { "userId": "u2", "nickname": "지훈", "avatar": { "color": "red_orange" } },
          "createdAt": "2026-08-01T09:00:00Z", "labelGroup": "manyComments"
        },
        {
          "id": "pin-2", "roomId": "room-1",
          "place": { "id": "place-2", "name": "을지다락", "address": "서울 중구 을지로3가",
                     "lat": 37.5662, "lng": 126.9917, "category": null, "mapUrl": null },
          "images": [], "createdBy": null,
          "createdAt": "2026-08-02T09:00:00Z", "labelGroup": "manyViews"
        }
      ]
    }
    """

    @Test("홈 덱은 GET api/v1/rooms/{roomId}/cards 로 나가고 기본 정렬은 ggukPick 이다")
    func cards_pathAndSort() async throws {
        let client = StubHTTPClient(json: Self.cardsJSON)
        let sut = PinRepositoryImpl(client: client)

        _ = try await sut.cards(roomID: "room-1", filter: .recommended, origin: nil)

        #expect(await client.lastPath == "api/v1/rooms/room-1/cards")
        #expect(await client.query("sort") == "ggukPick")
        #expect(await client.query("lat") == nil)
    }

    // 서버는 sort=nearby 에 좌표가 없으면 400 을 준다 — 좌표를 실어 보내는지 계약으로 고정한다.
    @Test("가까운순은 lat·lng 를 함께 싣는다")
    func cards_nearbyCarriesCoordinate() async throws {
        let client = StubHTTPClient(json: Self.cardsJSON)
        let sut = PinRepositoryImpl(client: client)

        _ = try await sut.cards(
            roomID: "room-1", filter: .nearby,
            origin: Coordinate(latitude: 37.5, longitude: 127.0)
        )

        #expect(await client.query("sort") == "nearby")
        #expect(await client.query("lat") == "37.5")
        #expect(await client.query("lng") == "127.0")
    }

    @Test("카드 응답이 핀으로 매핑된다 — 좌표·사진·저장자 색·라벨")
    func cards_mapsResponse() async throws {
        let sut = PinRepositoryImpl(client: StubHTTPClient(json: Self.cardsJSON))

        let pins = try await sut.cards(roomID: "room-1", filter: .recommended, origin: nil)

        #expect(pins.count == 2)
        #expect(pins[0].place.coordinate == Coordinate(latitude: 37.5443, longitude: 127.0557))
        #expect(pins[0].place.category == "카페")
        // 파싱되지 않는 문자열은 그 한 장만 버린다 — 통째로 비우면 사진 있는 장소가 없는 것처럼 보인다.
        #expect(pins[0].images.count == 1)
        #expect(pins[0].createdBy?.avatarColor == .redOrange)
        #expect(pins[0].category == .manyStories)
        #expect(pins[1].createdBy == nil)
        #expect(pins[1].place.mapURL == nil)
        #expect(pins[1].category == .popularAmongFriends)
    }

    // #196 회귀. 서버가 홈 헤더용 `room` 을 실으면서 카드가 `data.cards` 한 겹 안으로 들어갔는데
    // 앱은 `data` 를 배열로 읽고 있었다. 디코딩이 던지면 홈은 그 방을 후보 0건으로 삼켜
    // 사용자에게는 오류가 아니라 "모든 장소를 다 봤어요" 로 보인다 — 조용히 묻히는 실패라
    // 응답 모양을 여기서 못박는다.
    @Test("덱은 data 자체가 아니라 data.cards 에서 읽는다")
    func cards_readDeckFromObjectEnvelope() async throws {
        let sut = PinRepositoryImpl(client: StubHTTPClient(json: Self.cardsJSON))

        let pins = try await sut.cards(roomID: "room-1", filter: .recommended, origin: nil)

        #expect(pins.map(\.id.value) == ["pin-1", "pin-2"])
    }

    // `room` 은 ``PinCardDeckDTO`` 가 선언하지 않는다 — 홈 헤더는 방 목록에서 같은 값을 이미 받는다.
    // 스웨거가 이 응답에 `required` 를 적어 두지 않아 `room` 이 필수인지 확정할 수 없으므로,
    // 서버가 빼더라도 덱은 그대로 와야 한다.
    @Test("room 이 빠져도 덱은 디코딩된다 — 헤더용 메타라 덱과 무관하다")
    func cards_decodeWithoutRoomMeta() async throws {
        let sut = PinRepositoryImpl(client: StubHTTPClient(json: """
        { "cards": [
            { "id": "pin-1", "roomId": "room-1",
              "place": { "id": "p", "name": "n", "address": "a", "lat": 1, "lng": 2,
                         "category": null, "mapUrl": null },
              "images": [], "createdBy": null,
              "createdAt": "2026-08-01T09:00:00Z", "labelGroup": "worthVisiting" }
        ] }
        """))

        let pins = try await sut.cards(roomID: "room-1", filter: .recommended, origin: nil)

        #expect(pins.count == 1)
    }

    // 서버 라벨과 카드 뱃지는 이름이 다르고 뜻으로만 대응한다 — 어긋나면 카드에 남의 뱃지가 붙는다.
    @Test("라벨 4종이 각자의 뱃지로 매핑되고, 모르는 라벨은 가볼 만한 곳으로 떨어진다")
    func cards_labelMapping() async throws {
        let expected: [(String, PinCategory)] = [
            ("worthVisiting", .worthVisiting),
            ("manyViews", .popularAmongFriends),
            ("manySaves", .savedByMany),
            ("manyComments", .manyStories),
            ("somethingNew", .worthVisiting),
        ]

        for (label, category) in expected {
            let sut = PinRepositoryImpl(client: StubHTTPClient(json: Self.card(labelGroup: label)))
            let pins = try await sut.cards(roomID: "r", filter: .recommended, origin: nil)
            #expect(pins.first?.category == category, "\(label)")
        }
    }

    @Test("방 목록은 GET api/v1/pins?roomId 로 나간다 — page 를 붙이지 않아야 전체가 온다")
    func pins_pathAndQuery() async throws {
        let client = StubHTTPClient(json: "[]")
        let sut = PinRepositoryImpl(client: client)

        _ = try await sut.pins(roomID: "room-7")

        #expect(await client.lastPath == "api/v1/pins")
        #expect(await client.query("roomId") == "room-7")
        #expect(await client.query("page") == nil)
        #expect(await client.query("pageSize") == nil)
    }

    @Test("상세는 출처 링크를 함께 준다 — 없으면 nil")
    func detail_mapsSourceURL() async throws {
        let sut = PinRepositoryImpl(client: StubHTTPClient(json: """
        { "id": "pin-1", "roomId": "room-1",
          "place": { "id": "p", "name": "n", "address": "a", "lat": 1, "lng": 2,
                     "category": null, "mapUrl": null },
          "images": null, "createdBy": null, "createdAt": "2026-08-01T09:00:00Z",
          "sourceUrl": "https://www.instagram.com/p/abc/" }
        """))

        let detail = try await sut.pinDetail(id: PinID("pin-1"))

        #expect(detail.sourceURL?.absoluteString == "https://www.instagram.com/p/abc/")
        #expect(detail.pin.images.isEmpty)   // images 키가 null 이어도 목록이 깨지지 않는다
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let sut = PinRepositoryImpl(client: StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료")))

        await #expect(throws: DomainError.unauthorized) {
            try await sut.cards(roomID: "r", filter: .recommended, origin: nil)
        }
    }

    @Test("번역되지 않은 상태코드는 조회 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let sut = PinRepositoryImpl(client: StubHTTPClient(error: NetworkError.server(statusCode: 500)))

        await #expect(throws: DomainError.pinsFetchFailed) { try await sut.pins(roomID: "r") }
    }

    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let sut = PinRepositoryImpl(client: StubHTTPClient(error: NetworkError.cancelled))

        await #expect(throws: CancellationError.self) { try await sut.pins(roomID: "r") }
    }

    @Test("핀 삭제는 DELETE api/v1/pins/{pinId} 로 나간다")
    func delete_pathAndMethod() async throws {
        let client = StubHTTPClient(json: #"{"ok": true}"#)
        let sut = PinRepositoryImpl(client: client)

        try await sut.delete(pinID: PinID("pin-123"))

        #expect(await client.lastPath == "api/v1/pins/pin-123")
        #expect(await client.lastMethod == .delete)
    }

    @Test("핀 삭제 실패 시 pinDeleteFailed 로 번역된다")
    func delete_failureMapsToDomainError() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = PinRepositoryImpl(client: client)

        await #expect(throws: DomainError.pinDeleteFailed) {
            try await sut.delete(pinID: PinID("pin-123"))
        }
    }

    @Test("핀 삭제 중 취소는 CancellationError 로 유지된다")
    func delete_cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = PinRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.delete(pinID: PinID("pin-123"))
        }
    }

    private static func card(labelGroup: String) -> String {
        """
        { "room": { "id": "room-1", "type": "shared", "name": "맛집 탐방", "color": "red" },
          "cards": [
            { "id": "pin-1", "roomId": "room-1",
              "place": { "id": "p", "name": "n", "address": "a", "lat": 1, "lng": 2,
                         "category": null, "mapUrl": null },
              "images": [], "createdBy": null,
              "createdAt": "2026-08-01T09:00:00Z", "labelGroup": "\(labelGroup)" }
          ] }
        """
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private var lastQuery: [URLQueryItem] = []

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    func query(_ name: String) -> String? {
        lastQuery.first { $0.name == name }?.value
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastQuery = endpoint.queryItems

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 핀 조회는 전체 조회라 페이지네이션을 쓰지 않는다
    }
}
