import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 방 목록 조회의 계약을 고정한다 — 어떤 경로로 나가고, 응답이 어떤 방으로 매핑되며,
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
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    // Domain 에도 Page 가 생겨(목록 API 공용 값 타입) 두 모듈을 함께 import 하는 이 파일에서는 모호하다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 방 목록은 페이지네이션을 쓰지 않는다
    }
}
