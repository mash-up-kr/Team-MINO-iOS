import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 방 목록·단건 조회의 계약을 고정한다 — 어떤 경로로 나가고, 응답이 어떤 방으로 매핑되며,
/// 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("RoomRepositoryImpl")
struct RoomRepositoryImplTests {
    private static let listJSON = """
    [
      {
        "id": "room-1", "type": "personal", "name": "내 장소", "description": null,
        "color": "orange", "ownerId": "u1", "createdAt": "2026-08-01T09:00:00Z",
        "pinCount": 12, "memberCount": 1
      },
      {
        "id": "room-2", "type": "shared", "name": "성수 카페", "description": "주말에 가볼 곳",
        "color": "cyan", "ownerId": "u2", "createdAt": "2026-08-02T09:00:00.123Z",
        "pinCount": 8, "memberCount": 3
      }
    ]
    """

    @Test("GET api/v1/rooms 로 나가고 응답이 방으로 매핑된다")
    func rooms_mapsResponse() async throws {
        let client = StubHTTPClient(json: Self.listJSON)
        let sut = RoomRepositoryImpl(client: client)

        let rooms = try await sut.rooms()

        #expect(await client.lastPath == "api/v1/rooms")
        #expect(await client.lastMethod == .get)
        #expect(rooms.count == 2)
        #expect(rooms[0].type == .personal)
        #expect(rooms[0].color == .orange)
        #expect(rooms[0].pinCount == 12)
        #expect(rooms[1].description == "주말에 가볼 곳")
        #expect(rooms[1].color == .cyan)
    }

    // 서버가 팔레트에 없는 색 이름을 주더라도 목록 전체가 깨지면 안 된다.
    @Test("팔레트에 없는 색은 nil 로 떨어지고 나머지 필드는 살아남는다")
    func rooms_unknownColorBecomesNil() async throws {
        let client = StubHTTPClient(json: """
        [{ "id": "r", "type": "shared", "name": "방", "description": null,
           "color": "chartreuse", "ownerId": "u", "createdAt": "2026-08-01T09:00:00Z",
           "pinCount": 0, "memberCount": 1 }]
        """)
        let sut = RoomRepositoryImpl(client: client)

        let rooms = try await sut.rooms()

        #expect(rooms[0].color == nil)
        #expect(rooms[0].name == "방")
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = RoomRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) { try await sut.rooms() }
    }

    @Test("번역되지 않은 상태코드는 조회 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = RoomRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomsFetchFailed) { try await sut.rooms() }
    }

    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = RoomRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) { try await sut.rooms() }
    }

    // MARK: - 단건 조회

    private static let detailJSON = """
    { "id": "room-2", "type": "shared", "name": "성수 카페", "description": "주말에 가볼 곳",
      "color": "cyan", "ownerId": "u2", "createdAt": "2026-08-02T09:00:00.123Z",
      "pinCount": 8, "memberCount": 3 }
    """

    private static let membersJSON = """
    [
      { "userId": "u2", "nickname": "지은", "avatar": { "color": "red" },
        "isOwner": true, "joinedAt": "2026-08-02T09:00:00Z" },
      { "userId": "u3", "nickname": "형준", "avatar": null,
        "isOwner": false, "joinedAt": "2026-08-03T09:00:00Z" }
    ]
    """

    @Test("방 단건은 상세와 멤버 두 경로로 나간다")
    func room_requestsDetailAndMembers() async throws {
        let client = StubHTTPClient(jsonBySuffix: [
            "/members": Self.membersJSON,
            "api/v1/rooms/room-2": Self.detailJSON,
        ])
        let sut = RoomRepositoryImpl(client: client)

        _ = try await sut.room(id: "room-2")

        // 두 요청이 병렬로 나가므로 순서를 단언하지 않는다.
        #expect(await Set(client.paths) == ["api/v1/rooms/room-2", "api/v1/rooms/room-2/members"])
    }

    // 단건 응답에는 `users` 가 없다(스펙 확인). 멤버를 따로 받아 채우지 않으면 방 상세 헤더의
    // 아바타가 조용히 빈다 — 컴파일도 테스트도 통과하고 화면만 비는 회귀라 여기서 고정한다.
    @Test("단건 응답에 users 가 없어도 멤버 조회 결과로 채워진다")
    func room_fillsMembersFromSeparateCall() async throws {
        let client = StubHTTPClient(jsonBySuffix: [
            "/members": Self.membersJSON,
            "api/v1/rooms/room-2": Self.detailJSON,
        ])
        let sut = RoomRepositoryImpl(client: client)

        let room = try await sut.room(id: "room-2")

        #expect(room.name == "성수 카페")
        #expect(room.color == .cyan)
        #expect(room.pinCount == 8)
        #expect(room.users.count == 2)
        #expect(room.users[0].avatarColor == .red)
        #expect(room.users[1].avatarColor == nil)
    }

    @Test("지워졌거나 나간 방(404)은 조회 실패로 흡수된다")
    func room_notFoundFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.notFound(code: "NOT_FOUND", message: "없음"))
        let sut = RoomRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomsFetchFailed) { try await sut.room(id: "gone") }
    }

    @Test("단건 조회의 취소도 CancellationError 로 되돌아온다")
    func room_cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = RoomRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) { try await sut.room(id: "room-2") }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
///
/// 방 단건 조회는 한 번에 두 경로(상세·멤버)로 나가므로 **경로 꼬리로 응답을 고르는** 사전을 함께 받는다.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let jsonBySuffix: [String: String]
    private let error: Error?
    private(set) var paths: [String] = []
    private(set) var lastMethod: HTTPMethod?

    var lastPath: String? { paths.last }

    init(json: String? = nil, jsonBySuffix: [String: String] = [:], error: Error? = nil) {
        self.json = json
        self.jsonBySuffix = jsonBySuffix
        self.error = error
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        paths.append(endpoint.path)
        lastMethod = endpoint.method

        if let error { throw error }
        let body = jsonBySuffix.first { endpoint.path.hasSuffix($0.key) }?.value ?? json
        guard let body else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(body.utf8))
    }

    // Domain 에도 Page 가 생겨(목록 API 공용 값 타입) 두 모듈을 함께 import 하는 이 파일에서는 모호하다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 방 조회는 페이지네이션을 쓰지 않는다
    }
}
