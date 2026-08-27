import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 실 API Repository 의 계약을 고정한다 — 어떤 경로·메서드로 나가고, 인프라 오류가 어떤
/// 도메인 어휘로 번역되는지. `HTTPClient` 를 직접 스텁한다(URLProtocol 은 Networking 내부 전용).
@Suite("RoomEditingRepositoryImpl")
struct RoomEditingRepositoryImplTests {
    private static let successJSON = """
    {
      "id": "room-1", "type": "shared", "name": "맛집 탐방", "description": "설명",
      "color": "orange", "ownerId": "u1", "createdAt": "2026-08-01T09:00:00Z"
    }
    """

    // MARK: 생성

    @Test("생성은 POST api/v1/rooms 로 나가고 색을 이름으로 보낸다")
    func create_sendsNameAndColor() async throws {
        let client = StubHTTPClient(json: Self.successJSON)
        let sut = RoomEditingRepositoryImpl(client: client)

        let room = try await sut.create(name: "맛집 탐방", description: "설명", color: .orange)

        #expect(await client.lastPath == "api/v1/rooms")
        #expect(await client.lastMethod == .post)
        #expect(await client.lastBodyValue("name") == "맛집 탐방")
        #expect(await client.lastBodyValue("description") == "설명")
        #expect(await client.lastBodyValue("color") == "orange")
        #expect(room.id == "room-1")
        #expect(room.color == .orange)
    }

    // 생성 응답에는 pinCount·memberCount 가 없다 — 없어도 방이 만들어져야 한다.
    @Test("개수 필드 없는 생성 응답도 방으로 매핑된다")
    func create_responseWithoutCounts() async throws {
        let client = StubHTTPClient(json: Self.successJSON)
        let sut = RoomEditingRepositoryImpl(client: client)

        let room = try await sut.create(name: "맛집 탐방", description: nil, color: .orange)

        #expect(room.pinCount == 0)
        #expect(room.memberCount == 0)
        #expect(room.users.isEmpty)
    }

    @Test("설명이 nil 이면 요청 본문에서 키가 빠진다")
    func create_omitsNilDescription() async throws {
        let client = StubHTTPClient(json: Self.successJSON)
        let sut = RoomEditingRepositoryImpl(client: client)

        _ = try await sut.create(name: "맛집 탐방", description: nil, color: .red)

        #expect(await client.lastBodyValue("description") == nil)
    }

    // MARK: 수정

    @Test("수정은 PATCH api/v1/rooms/{id} 로 나간다")
    func update_targetsRoomPath() async throws {
        let client = StubHTTPClient(json: Self.successJSON)
        let sut = RoomEditingRepositoryImpl(client: client)

        _ = try await sut.update(roomId: "room-42", name: "새 이름", description: nil, color: .lightBlue)

        #expect(await client.lastPath == "api/v1/rooms/room-42")
        #expect(await client.lastMethod == .patch)
        #expect(await client.lastBodyValue("color") == "lightBlue")
    }

    // MARK: 오류 번역

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = RoomEditingRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.create(name: "맛집 탐방", description: nil, color: .red)
        }
    }

    @Test("방장이 아니면(403) 저장 실패로 수렴한다 — 구분해 보여줄 화면이 아직 없다")
    func forbiddenBecomesSaveFailure() async {
        let client = StubHTTPClient(error: NetworkError.forbidden(code: "NOT_OWNER", message: "권한 없음"))
        let sut = RoomEditingRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomSaveFailed) {
            try await sut.update(roomId: "room-1", name: "이름", description: nil, color: .red)
        }
    }

    @Test("번역되지 않은 상태코드도 저장 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = RoomEditingRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomSaveFailed) {
            try await sut.create(name: "맛집 탐방", description: nil, color: .red)
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = RoomEditingRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.create(name: "맛집 탐방", description: nil, color: .red)
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
/// 응답은 **JSON 을 실제로 디코드**해 돌려준다 — 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubHTTPClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private(set) var lastBody: [String: Any]?

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    /// 요청 본문의 문자열 값. 키 자체가 없으면 nil.
    func lastBodyValue(_ key: String) -> String? {
        lastBody?[key] as? String
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    // Domain 에도 같은 이름의 `Page` 가 있어 모듈로 한정한다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 방 생성·수정은 페이지네이션을 쓰지 않는다
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
