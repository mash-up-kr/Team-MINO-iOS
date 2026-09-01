import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 「다른 방에 공유」 후보 조회의 계약을 고정한다(place-api.md §3) —
/// **장소 id** 로 나가고, `hasPlace` 가 "이미 저장됨" 으로 매핑되며, 멤버 목록은 받지 않는다.
@Suite("ShareTargetRepositoryImpl")
struct ShareTargetRepositoryImplTests {
    private static let placeID = PlaceID("place-1")

    private static let listJSON = """
    [
      {
        "id": "room-1", "type": "personal", "name": "내 장소", "description": null,
        "color": "orange", "ownerId": "u1", "createdAt": "2026-08-01T09:00:00Z",
        "pinCount": 12, "memberCount": 1, "hasPlace": true
      },
      {
        "id": "room-2", "type": "shared", "name": "성수 카페", "description": null,
        "color": "cyan", "ownerId": "u2", "createdAt": "2026-08-02T09:00:00Z",
        "pinCount": 8, "memberCount": 3, "hasPlace": false
      }
    ]
    """

    @Test("GET api/v1/rooms 에 showHasPlaceId 를 장소 id 로 실어 보낸다")
    func sendsPlaceIDQuery() async throws {
        let client = StubHTTPClient(json: Self.listJSON)
        let sut = ShareTargetRepositoryImpl(client: client)

        _ = try await sut.shareTargets(placeID: Self.placeID)

        #expect(await client.lastPath == "api/v1/rooms")
        #expect(await client.lastMethod == .get)
        #expect(await client.lastQuery["showHasPlaceId"] == "place-1")
    }

    // 계약 §3: "showUsers 는 쓰지 않는다(시트 카드에 멤버 아바타를 넣지 않는다)".
    @Test("showUsers 는 붙이지 않는다 — 시트가 멤버 아바타를 그리지 않는다")
    func doesNotRequestUsers() async throws {
        let client = StubHTTPClient(json: Self.listJSON)
        let sut = ShareTargetRepositoryImpl(client: client)

        _ = try await sut.shareTargets(placeID: Self.placeID)

        #expect(await client.lastQuery["showUsers"] == nil)
    }

    @Test("hasPlace 가 '이미 저장됨' 으로 매핑된다 — 그 방을 체크·비활성으로 그린다(FR-018)")
    func mapsHasPlaceToAlreadySaved() async throws {
        let client = StubHTTPClient(json: Self.listJSON)
        let sut = ShareTargetRepositoryImpl(client: client)

        let targets = try await sut.shareTargets(placeID: Self.placeID)

        #expect(targets.map(\.room.id) == ["room-1", "room-2"])
        #expect(targets.map(\.alreadySaved) == [true, false])
    }

    // 키가 통째로 빠지는 경우(쿼리를 안 붙였거나 서버가 생략) — 담긴 방을 안 담겼다고 보이면
    // 사용자가 한 번 더 고르고 409 로 끝나지만, 반대로 보이면 담을 수 있는 방을 막아 버린다.
    @Test("hasPlace 가 없으면 '안 담김' 으로 본다")
    func missingHasPlaceIsNotSaved() async throws {
        let client = StubHTTPClient(json: """
        [{ "id": "r", "type": "shared", "name": "방", "description": null,
           "color": "cyan", "ownerId": "u", "createdAt": "2026-08-01T09:00:00Z",
           "pinCount": 0, "memberCount": 1 }]
        """)
        let sut = ShareTargetRepositoryImpl(client: client)

        let targets = try await sut.shareTargets(placeID: Self.placeID)

        #expect(targets[0].alreadySaved == false)
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = ShareTargetRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            _ = try await sut.shareTargets(placeID: Self.placeID)
        }
    }

    @Test("번역되지 않은 상태코드도 방 조회 실패로 떨어진다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = ShareTargetRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomsFetchFailed) {
            _ = try await sut.shareTargets(placeID: Self.placeID)
        }
    }

    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = ShareTargetRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            _ = try await sut.shareTargets(placeID: Self.placeID)
        }
    }
}

/// 요청의 경로·쿼리를 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private(set) var lastQuery: [String: String] = [:]

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastQuery = Dictionary(
            uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value ?? "") }
        )

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 방 목록은 페이지네이션을 쓰지 않는다
    }
}
