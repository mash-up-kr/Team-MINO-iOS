import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 링크 저장의 계약을 고정한다 — 어떤 경로·메서드로 나가고, 링크와 방 목록이 한 요청에 실리며,
/// 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("SaveLinkRepositoryImpl")
struct SaveLinkRepositoryImplTests {
    private static let link = URL(string: "https://www.instagram.com/reel/abc123/")!

    @Test("POST api/v1/rooms/pins 한 번으로 링크와 고른 방들을 함께 보낸다")
    func save_sendsSingleRequestWithAllRooms() async throws {
        let client = StubHTTPClient()
        let sut = SaveLinkRepositoryImpl(client: client)

        try await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2", "room-3"])

        #expect(await client.callCount == 1)
        #expect(await client.lastPath == "api/v1/rooms/pins")
        #expect(await client.lastMethod == .post)
        #expect(await client.lastURL == Self.link.absoluteString)
        #expect(await client.lastRoomIDs == ["room-1", "room-2", "room-3"])
    }

    @Test("방이 하나여도 배열로 실린다")
    func save_singleRoomStillArray() async throws {
        let client = StubHTTPClient()
        let sut = SaveLinkRepositoryImpl(client: client)

        try await sut.save(url: Self.link, toRoomIDs: ["room-1"])

        #expect(await client.lastRoomIDs == ["room-1"])
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1"])
        }
    }

    // 이미 그 방에 있는 링크(400 DUPLICATE_PIN_IN_ROOM)도 실패로 흡수한다 —
    // 시안에 중복 저장을 따로 알리는 자리가 없어 구분해도 보여줄 곳이 없다.
    @Test("중복 저장(400)도 저장 실패로 수렴한다")
    func duplicateBecomesFailure() async {
        let client = StubHTTPClient(
            error: NetworkError.badRequest(code: "DUPLICATE_PIN_IN_ROOM", message: "이미 있음")
        )
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.linkSaveFailed) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2"])
        }
    }

    @Test("번역되지 않은 상태코드도 저장 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.linkSaveFailed) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1"])
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1"])
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
private actor StubHTTPClient: HTTPClient {
    private let error: Error?
    private(set) var callCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private var lastBody: [String: Any]?

    init(error: Error? = nil) {
        self.error = error
    }

    var lastURL: String? { lastBody?["url"] as? String }
    /// 순서를 고정해 비교한다 — `Set` 을 배열로 옮기므로 나가는 순서는 정해져 있지 않다.
    var lastRoomIDs: [String]? { (lastBody?["roomIds"] as? [String])?.sorted() }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        callCount += 1
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        // 202 는 본문이 없다 — 클라이언트가 빈 본문을 OkResponse 로 통과시키는 자리를 흉내낸다.
        return try APIDecoder.make().decode(T.self, from: Data(#"{"ok":true}"#.utf8))
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 핀 저장은 페이지네이션을 쓰지 않는다
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
